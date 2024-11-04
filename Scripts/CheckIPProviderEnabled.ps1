<#

.SYNOPSIS
    Script to Determine if any Service Fabric cluster has Open Networking feature enabled and is not running on a patched version 
    Also checking if cluster is running 7.0 =>7.0CU3 (7.0.455 => 7.0.469) using Windows Container feature (irrespective of whether open network feature is enabled or disabled)

.DESCRIPTION
    Usage Instructions: .\CheckIPProviderEnabled.ps1 @("{subscription id 1}", "{subscription id 1}", "{subscription id ...}")

.PARAMETER subscriptionIdArray
    [required][string array] Azure SubscriptionId array

#>

Param(
    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]
    [string[]]$subscriptionIdArray = @("1895EE10-CF9D-4B6D-820C-687A4E565636","6DD0137A-1A1E-4310-91CD-D9D6D9929F18")
)
Set-StrictMode -Version 3
$ErrorActionPreference = "Continue"
$issuesFound = 0

$patchedVersionsTable = @{
    Windows_70 = "7.0.478.9590"
    Windows_71 = "7.1.459.9590"
    Windows_72 = "7.2.413.9590"
    Ubuntu_16_70 = "7.0.472.1"
    Ubuntu_16_71 = "7.1.455.1"
    Ubuntu_1804_71 = "7.1.455.1804"
}

if (!(Get-AzContext)) {
        write-host "connecting to azure"
        Connect-AzAccount
    }
   
ForEach($subscriptionId in $subscriptionIdArray)
{
    Write-Host
    Write-Host "Setting context to subscriptionId" $subscriptionId
    Write-Host
    Set-AzContext -SubscriptionId $subscriptionId    

    $clusters = Get-AzResource -ResourceType "Microsoft.ServiceFabric/clusters"

    foreach($cluster in $clusters)
    {
        # get the cluster manifest
        $manifest = Get-AzServiceFabricCluster -ResourceGroupName $cluster.ResourceGroupName -ClusterName $cluster.Name        
        $hosting = $manifest.FabricSettings
        $upgradeMode = $manifest.UpgradeMode
        $clusterVersion = [version]$manifest.ClusterCodeVersion

        # Calculate Patch Level
        if($clusterVersion.Revision -like '1*')
        {
            #Modified by Reshma V, Due to OS system mismatch with patchedVersionsTable the patch version was always empty for Linux clusters
            if($clusterVersion.Revision -like '1804*') {
                $operatingSystem = "Ubuntu_1804"
            } else {
                $operatingSystem = "Ubuntu_16"
            }
        }
        else
        {
            $operatingSystem = "Windows"
        }

        $lookupIndex = $operatingSystem + "_" + $clusterVersion.Major + $clusterVersion.Minor
        $PatchLevel = [version]$patchedVersionsTable[$lookupIndex]

        # check if we are on a version too low
        if(($clusterVersion.Major -lt 6) `
            -or (($clusterVersion.Major -eq 6) -and (($clusterVersion.Minor -lt 4))) `
            )
        { $lowVersion = $true } else { $lowVersion = $false }

        $is7EdgeCase = 0;

        # check if we are on a 7.0 =>7.0CU3 (7.0.455 => 7.0.469) and using Windows Container Feature
        if( ($clusterVersion.Major -eq 7) -and ($clusterVersion.Minor -eq 0) -and ($clusterVersion.Build -lt 470))
        { 
            $vmssList = get-azvmss -ResourceGroupName $cluster.ResourceGroupName

            foreach($vmss in $vmssList)
            {
                $vmssVm = Get-AzVmssVM -ResourceGroupName $cluster.ResourceGroupName -VMScaleSetName $vmss.Name -InstanceId 0
                $OsType = $vmssVm.StorageProfile.OsDisk.OsType
                $OsSku = $vmssVm.StorageProfile.ImageReference.Sku
                if($OsType -eq 'Windows' -and $OsSku -like '*with-Containers*') {
                    $is7EdgeCase++
                }
            }
        } 

        Write-Host " "

        # check if the Open Network feature is enabled
        try {$IPProvider = $hosting.Parameters | Where-Object -Property Name -eq "IPProviderEnabled"} catch {}

        if((($IPProvider) -and ($IPProvider -eq $true)) -or ($is7EdgeCase -gt 0))
        {
            if(($clusterVersion.Major -eq $PatchLevel.Major) `
            -and ($clusterVersion.Minor -eq $PatchLevel.Minor) `
            -and ($clusterVersion.Build -ge $PatchLevel.Build) `
            )
            {
                Write-Host "     OK: " $manifest.Id
                Write-Host "        Open Networking in use: " $IPProvider.Value
                Write-Host "                  Code Version: " $clusterVersion
                Write-Host "                 Patch Version: " $PatchLevel
                Write-Host "                  Upgrade Mode: " $upgradeMode
            }
            else
            {
                $issuesFound++
                Write-Host "   **Problem** resourceId: " $manifest.Id -ForegroundColor Red
                if(($IPProvider) -and ($IPProvider -eq $true))
                {
                    Write-Host "                    Open Networking in use: " $IPProvider.Value
                }
                Write-Host "      7.0 < CU4 w/Container Feature in use: " ($is7EdgeCase -gt 0)
                Write-Host "                              Code Version: " $clusterVersion
                Write-Host "                             Patch Version: " $PatchLevel
                Write-Host "                              Upgrade Mode: " $upgradeMode
                if($lowVersion) { 
                    $issuesFound++ 
                    Write-Host "    SF CodeVersion is vulnerable and Open Networking feature is enabled!  Please upgrade immediately to a supported/patched version of Service Fabric to avoid service disruptions, otherwise please disable this feature." -ForegroundColor Red
                }
                if($is7EdgeCase -gt 0) { 
                    $issuesFound++ 
                    Write-Host "    SF CodeVersion is 7.0 =>7.0CU3 (7.0.455 => 7.0.469) and using Windows Container Feature on one or more nodetypes.  Please upgrade immediately to a supported/patched version of Service Fabric to avoid service disruptions." -ForegroundColor Red
                }
            }
        } else {
            if($lowVersion)
            {
                $issuesFound++ 
                Write-Host "   **Problem** resourceId: " $manifest.Id -ForegroundColor Red
                Write-Host "                    Open Networking in use: " $lowVersion
                Write-Host "                              Code Version: " $clusterVersion
                Write-Host "                              Upgrade Mode: " $upgradeMode
                Write-Host "    SF CodeVersion is < 6.4, please upgrade immediately to a supported/patched version of Service Fabric to avoid service disruptions." -ForegroundColor Red
            }
            else
            {
                Write-Host "     OK: " $manifest.Id
                Write-Host "        Open Networking in use: False" 
                Write-Host "                  Code Version: " $clusterVersion
                Write-Host "                 Patch Version: " $PatchLevel
                Write-Host "                  Upgrade Mode: " $upgradeMode
            }            
        }
    }
}

Write-Host "Checks complete.."

if($issuesFound -eq 0)
{
    Write-Host "All Clear - no issues were found!"
}