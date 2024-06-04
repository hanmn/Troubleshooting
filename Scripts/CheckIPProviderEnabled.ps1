<#

.SYNOPSIS
    Script to Determine if any Service Fabric cluster is vulnerable to Schenker -SSIRP 2034

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

$patchedVersionsTable = @{
    Windows_70 = "7.0.478.9590"
    Windows_71 = "7.1.459.9590"
    Windows_72 = "7.2.413.9590"
    Ubuntu_16_70 = "7.0.472.1"
    Ubuntu_16_71 = "7.1.455.1"
    Ubuntu_1804_71 = "7.1.455.1804"
}

Login-AzAccount
   
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
        $clusterVersion = $manifest.ClusterCodeVersion

        # Calculate Patch Level
        $codeVersion = $clusterVersion.Split('.') | Select-Object -First 4
        if($codeVersion[3] -like '1*')
        {
            $operatingSystem = "Linux"
        }
        else
        {
            $operatingSystem = "Windows"
        }

        $lookupIndex = $operatingSystem + "_" + $codeVersion[0] + $codeVersion[1]
        $PatchLevel = $patchedVersionsTable[$lookupIndex]
        $PatchVersion = $PatchLevel.Split('.') | Select-Object -First 4

        # check if we are on a version too low
        if(($clusterVersion[0] -lt 6) `
            -or (($clusterVersion[0] -eq 6) -and (($clusterVersion[1] -lt 4))) `
            )
        { $lowVersion = $true } else { $lowVersion = $false }


        # check if the Open Network feature is enabled
        try {$IPProvider = $hosting.Parameters | Where-Object -Property Name -eq "IPProviderEnabled"} catch {}

        if(($IPProvider) -and ($IPProvider.Value = $true))
        {
            if(($clusterVersion[0] -eq $PatchVersion[0]) `
            -and ($clusterVersion[1] -eq $PatchVersion[1]) `
            -and ($clusterVersion[3] -ge $PatchVersion[3]) `
            )
            {
                Write-Host "     OK: " $manifest.Id
                Write-Host "        Open Networking in use: " $IPProvider.Value
                Write-Host "                  Code Version: " $clusterVersion
                Write-Host "                 Patch Version: " $PatchLevel
            }
            else
            {
                Write-Host "   **Problem** resourceId: " $manifest.Id -ForegroundColor Red
                Write-Host "        Open Networking in use: " $IPProvider.Value
                Write-Host "                  Code Version: " $clusterVersion
                Write-Host "                 Patch Version: " $PatchLevel
                Write-Host "    SF CodeVersion is vulnerable and feature is enabled!  If you are using the open networking feature, please upgrade by Nov 15, 2020 to a supported/patched version of Service Fabric to avoid service disruptions, otherwise please disable this feature." -ForegroundColor Red            }

        } else {
            if($lowVersion)
            {
                Write-Host "   **Problem** resourceId: " $manifest.Id -ForegroundColor Red
                Write-Host "        Open Networking in use: False" 
                Write-Host "                  Code Version: " $clusterVersion
                Write-Host "    SF CodeVersion is < 6.4, please upgrade by Nov 15, 2020 to a supported/patched version of Service Fabric to avoid service disruptions." -ForegroundColor Red
            }
            else
            {
                Write-Host "     OK: " $manifest.Id
                Write-Host "        Open Networking in use: False" 
                Write-Host "                  Code Version: " $clusterVersion
                Write-Host "                 Patch Version: " $PatchLevel
            }            
        }
    }
}

