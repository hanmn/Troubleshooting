#Requires -Version 3.0
# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.  All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# Feedback : pkc@microsoft.com
# ------------------------------------------------------------

<#
 .SYNOPSIS
    Fix the Service Fabric Cluster with Expired Certificate (Self Signed only)

 .DESCRIPTION
    Script can be used to recover the Service Fabric cluster with expired certificate. 

 .PARAMETER nodeIpArray
    By default script will automatically grab the IP address for all the nodes

 .PARAMETER clusterDataRootPath
    Cluster data root path. default 'd:\svcfab'

 .PARAMETER tempPath
    A temporary working folder to copy and work with Cluster Manifest and Settings files

 .PARAMETER cacheCredentials
    switch to optionally enable storing credentials in $global:creds variable.
    to clear, execute: $global:creds=$null

.PARAMETER localOnly
    switch to optionally run script only on local node.
    use when there are connectivity issues between nodes by rdp'ing to each node and running with this switch.

.LINK
    iwr https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/FixExpiredCert-AEPCC.ps1 -out $pwd/FixExpiredCert-AEPCC.ps1
#>

Param(
    [ValidateNotNullOrEmpty()]
    [string[]] $nodeIpArray = @("0"),
    [string]$clusterDataRootPath = 'd:\svcfab',
    [ValidateNotNullOrEmpty()]
    [string]$tempPath = 'd:\temp\certwork',
    [switch]$cacheCredentials,
    [switch]$localOnly
)

$ErrorActionPreference = 'continue'
$supportedVersion = [version]"6.5.658.9590"
$currentVersion = [version]"0.0"
$startTime = get-date
$global:failNodes = @()
$global:successNodes = @()
$SFEnv = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Service Fabric" 
$defaultBinary = 'C:\Program Files\Microsoft Service Fabric\bin\FabricHost.exe'
$creds = $null

if ($SFEnv.FabricDataRoot) {
    $clusterDataRootPath = $SFEnv.FabricDataRoot
}

if ($SFEnv.FabricVersion) {
    $currentVersion = $SFEnv.FabricVersion
}
else {
    $currentVersion = [io.fileinfo]::new($defaultBinary).VersionInfo.FileVersion
}

#Verifying whether SF Runtime is un supported version for AEPCC parameter 
if ($currentVersion -lt $supportedVersion ) {
    write-warning "This Script is supported for the Service Fabric runtime version greater than $supportedVersion. 
        Please leverage external TSG 
        'https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/Fix%20Expired%20Cluster%20Certificate%20Automated%20Script.md' 
        for fixing the issue with : $($SFEnv.FabricVersion )"
    return
}

If (!(Test-Path $clusterDataRootPath)) {
    write-warning $clusterDataRootPath " not found, exiting."
    return
}

#Saving current list of Trusted Hosts
$curValue = (get-item wsman:\localhost\Client\TrustedHosts).value

$scriptBlock = { 
    param($clusterDataRootPath, $tempPath)
    <#
        .SYNOPSIS
        . Updating Cluster Manifest file with AEPCC Parameter  
        #>
    function updateManifest {            
        Write-Host "$env:computername : Begin updating ClusterManifest.xml File"
        $manFile = $tempPath + "\clustermanifest.current.xml"
        $newManifest = $tempPath + "\modified_clustermanifest.xml"
        #Checking the AEPCC property value        
        [object]$tempManAEPCC = get-content $manFile | select-string -pattern '<Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="false" />' -AllMatches
        
        if ($tempManAEPCC) {
            Write-Host "$env:computername : AEPCC is False"
            $intermediateManifest = $tempPath + "\intermediate_clustermanifest.xml"
            get-content $manFile | ? { $_.trim() -ne '<Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="false" />' } | set-content $intermediateManifest 
            $manFile = $intermediateManifest
        }
        
        $ModContent = Get-Content -Path $manFile |
        ForEach-Object {
            # Output the existing line to pipeline in any case
            $_
            
            if ($_ -match '<Section Name="Security">' ) {
                '      <Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="true" />'
            }
        }

        $ModContent | Out-File -FilePath $newManifest -Encoding Default -Force  
                
        Write-Host "$env:computername : Updated the ClusterManifest.xml File : $newManifest"
        
    }
    <#
        .SYNOPSIS
        . Updating Cluster Setting file with AEPCC Parameter  
        #>

    function updateSettings {       
        Write-Host "$env:computername : Begin updating Settings.xml File"
        $settingFile = $tempPath + "\Settings.xml"
        $newSettings = $tempPath + "\modified_settings.xml"

        #Checking the AEPCC property value 

        [object]$tempSettingAEPCC = get-content $settingFile | select-string -pattern '<Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="false" />' -AllMatches
        if ($tempSettingAEPCC) {
            Write-Host "$env:computername : AEPCC is False"
            $intermediateSettings = $tempPath + "\intermediate_Settings.xml"
            get-content $settingFile | ? { $_.trim() -ne '<Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="false" />' } | set-content $intermediateSettings 
            $settingFile = $intermediateSettings
        }                   
        
        $ModContent = Get-Content -Path $settingFile |
        ForEach-Object {             
            $_
    
            if ($_ -match '<Section Name="Security">' ) {
                '    <Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="true" />'
            }
        }
        
        $ModContent | Out-File -FilePath $newSettings -Encoding Default -Force
        Write-Host "$env:computername : Updated Settings.xml $newSettings"
    }

    <#
        .SYNOPSIS
        . Stopping both SFNBA and FabricHost
        #>
    function StopServiceFabricServices {
        if ($(Get-Process | ? ProcessName -like "*FabricInstaller*" | measure).Count -gt 0) {
            Write-Warning "$env:computername : Found FabricInstaller running, may cause issues if not stopped, consult manual guide..."
            Write-Host "$env:computername : Pausing (15s)..."
            Start-Sleep -Seconds 15
        }

        $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
        $fabricHost = "FabricHostSvc"

        $bootstrapService = Get-Service -Name $bootstrapAgent
        if ($bootstrapService.Status -eq "Running") {
            Stop-Service $bootstrapAgent -ErrorAction SilentlyContinue
            Write-Host "$env:computername : Stopping $bootstrapAgent service" 
        }
        Do {
            Start-Sleep -Seconds 1
            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Stopped") {
                Write-Host "$env:computername : $bootstrapAgent now stopped" 
            }
            else {
                Write-Host "$env:computername : $bootstrapAgent current status: $($bootstrapService.Status)"
            }

        } While ($bootstrapService.Status -ne "Stopped")

        $fabricHostService = Get-Service -Name $fabricHost
        if ($fabricHostService.Status -eq "Running") {
            Stop-Service $fabricHost -ErrorAction SilentlyContinue
            Write-Host "$env:computername : Stopping $fabricHost service" 
        }
        Do {
            Start-Sleep -Seconds 1
            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Stopped") {
                Write-Host "$env:computername : $fabricHost now stopped" 
            }
            else {
                Write-Host "$env:computername : $fabricHost current status: $($fabricHostService.Status)"
            }

        } While ($fabricHostService.Status -ne "Stopped")
    }

    <#
        .SYNOPSIS
        . Starting both SFNBA and FabricHost
        #>
    function StartServiceFabricServices {
        $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
        $fabricHost = "FabricHostSvc"

        $fabricHostService = Get-Service -Name $fabricHost
        if ($fabricHostService.Status -eq "Stopped") {
            Start-Service $fabricHost -ErrorAction SilentlyContinue
            Write-Host "$env:computername : Starting $fabricHost service" 
        }
        Do {
            Start-Sleep -Seconds 1
            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Running") {
                Write-Host "$env:computername : $fabricHost now running" 
            }
            else {
                Write-Host "$env:computername : $fabricHost current status: $($fabricHostService.Status)"
            }

        } While ($fabricHostService.Status -ne "Running")

        $bootstrapService = Get-Service -Name $bootstrapAgent
        if ($bootstrapService.Status -eq "Stopped") {
            Start-Service $bootstrapAgent -ErrorAction SilentlyContinue
            Write-Host "$env:computername : Starting $bootstrapAgent service" 
        }

        do {
            Start-Sleep -Seconds 1
            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Running") {
                Write-Host "$env:computername : $bootstrapAgent now running" 
            }
            else {
                Write-Host "$env:computername : $bootstrapAgent current status: $($bootstrapService.Status)"
            }

        } While ($bootstrapService.Status -ne "Running")
    }

    #config files we need
    #"D:\SvcFab\ClusterManifest.current.xml"
    #"D:\SvcFab\<<node name>>\Fabric\Fabric.Config.<highest version> \Settings.xml"

    $result = Get-ChildItem -Path $clusterDataRootPath -Filter "Fabric.Data" -Directory -Recurse
    $hostPath = $result.Parent.Parent.Name 
        
    Write-Host "---- Node Name  :  " $hostPath 
    Write-Host "---------------------------------------------------------------------------------------------------------"

    $manifestPath = $clusterDataRootPath + "\" + $hostPath + "\Fabric\ClusterManifest.current.xml"
    $infrastructureManifest = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Data\InfrastructureManifest.xml"
        
    # Validating whether Manifest file already contain AEPCC parameter with true                   
    [object]$tempAEPCC = get-content $manifestPath | select-string -pattern '<Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="true" />' -AllMatches
                
    If (!$tempAEPCC) {
        #to get the settings.xml we need to determine the current version
        #"D:\SvcFab\<node name>\Fabric\Fabric.Package.current.xml" --> Read to determine version# <ConfigPackage Name="Fabric.Config" Version="1.131523081591497214" />
        $currentPackage = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Package.current.xml"
        $currentPackageXml = [xml](Get-Content $currentPackage)
        $packageName = $currentPackageXml.ServicePackage.DigestedConfigPackage.ConfigPackage | Select-Object -ExpandProperty Name
        $packageVersion = $currentPackageXml.ServicePackage.DigestedConfigPackage.ConfigPackage | Select-Object -ExpandProperty Version
        $SettingsFile = $clusterDataRootPath + "\" + $hostPath + "\Fabric\" + $packageName + "." + $packageVersion + "\settings.xml"
        $SettingsPath = $clusterDataRootPath + "\" + $hostPath + "\Fabric\" + $packageName + "." + $packageVersion
        Write-Host "$env:computername : Settings file: " $SettingsFile
        Write-Host "$env:computername : Settings path: " $SettingsPath

        # create a temp folder
        $tempFolder = New-Item -ItemType Directory -Force -Path $tempPath 

        Write-Host "$env:computername : Created the temp Work folder :" $tempFolder

        #copy current config to the temp folder
        Copy-Item -Path $manifestPath -Destination $tempPath -Force -Verbose
        $newManifest = $tempPath + "\modified_clustermanifest.xml"
        Copy-Item -Path $SettingsFile -Destination $tempPath -Force -Verbose
        $newSettings = $tempPath + "\modified_settings.xml"            

        # Appending cluster manifest File with AcceptExpiredPinnedClusterCertificate with value true
        updateManifest

        # Appending cluster Settings File with AcceptExpiredPinnedClusterCertificate with value true
        updateSettings

        ### Backup.... 
        $backupSettingsFile = $SettingsPath + "\settings_backup.xml"
        Copy-Item -Path $SettingsFile -Destination $backupSettingsFile -Force -Verbose
        Copy-Item -Path $newSettings -Destination $SettingsFile -Force -Verbose

        #stop these services
        Write-Host "$env:computername : Stopping services"
        StopServiceFabricServices

        #update the node configuration
        $logRoot = $clusterDataRootPath + "\Log"
        Write-Host "$env:computername : Updating Node configuration with new setting AcceptExpiredPinnedClusterCertificate " 
        
        #For Debugging 
        Write-Host "$env:computername : Cluster Manifest $newManifest"
        Write-Host "$env:computername : Log Root $logRoot"
        Write-Host "$env:computername : Cluster Data Path  : $clusterDataRootPath"
        Write-Host "$env:computername : Infra : $infrastructureManifest"
        
        New-ServiceFabricNodeConfiguration -FabricDataRoot $clusterDataRootPath -FabricLogRoot $logRoot -ClusterManifestPath $newManifest -InfrastructureManifestPath $infrastructureManifest 
        Write-Host "$env:computername : Updating Node configuration complete"

        #restart these services
        Write-Host "$env:computername : Starting services "
        StartServiceFabricServices
    }
    else {
        Write-Host "$env:computername : Manifest File already contains the AEPCC parameter $nodeIpAddress"
    }
}

if ($localOnly) {
    write-host "executing on local node only"
    invoke-command -ScriptBlock $scriptBlock -ArgumentList $clusterDataRootPath, $tempPath
    return
}

if (!$global:creds) {
    Write-Host "Enter your RDP Credentials"
    $creds = Get-Credential

    if ($cacheCredentials) {
        $global:creds = $creds
    }
}

function fixNodes($title, $scriptBlock, $nodeIpArray) {
    $count = 0

    ForEach ($nodeIpAddress in $nodeIpArray) {
        $count++
        #Verifying whether corresponding VM is up and running
        if (Test-Connection -ComputerName $nodeIpAddress -Quiet) {
            $activity = "$title : total minutes: $(((get-date) - $startTime).TotalMinutes.tostring("0.0")). connecting to: $nodeIpAddress  ($count of $($nodeIpArray.Count))"
            $status = "success: $($global:successNodes | sort -Unique) fail: $($global:failNodes | sort -Unique)"
            Write-Progress -Activity $activity `
                -Status $status `
                -PercentComplete (($count / $nodeIpArray.Count) * 100)
            write-host "updating trustedhosts list" -foregroundcolor green
            set-item wsman:\localhost\Client\TrustedHosts -value $nodeIpAddress -Force   
            Write-Host "---------------------------------------------------------------------------------------------------------"
            Write-Host "---- Node IP    :" $nodeIpAddress
                
            Start-Sleep(1)

            $error.clear()
            Invoke-Command -Authentication Negotiate -ComputerName $nodeIpAddress {
                $temp = Set-NetFirewallRule -DisplayGroup  'File and Printer Sharing' -Enabled True -PassThru |
                Select-Object DisplayName, Enabled
            } -Credential ($creds)

            if ($error) {
                $global:failNodes += $nodeIpAddress
                continue
            }

            #******************************************************************************
            # Script body
            # Execution begins here
            #******************************************************************************
                
            $error.clear()
            Invoke-Command -Authentication Negotiate -Computername $nodeIpAddress -Scriptblock $scriptBlock -ArgumentList $clusterDataRootPath, $tempPath
                
            if ($error) {
                $global:failNodes += $nodeIpAddress
            }
            else {
                $global:successNodes += $nodeIpAddress
            }
        }
        else {
            Write-Warning "$env:computername : unable to connect to node: $nodeIpAddress"
            $global:failNodes += $nodeIpAddress
        }
    }
    Write-Progress -Completed -Activity "complete"
}

<#
    .SYNOPSIS
    Get the list of seed nodes
    #>
if ($nodeIpArray[0] -eq 0 ) {
    Write-Host "Getting Seed node details" -foregroundcolor green
    $result = Get-ChildItem -Path $clusterDataRootPath -Filter "Fabric.Data" -Directory -Recurse
    $hostPath = $result.Parent.Parent.Name 
    $manifestPath = $clusterDataRootPath + "\" + $hostPath + "\Fabric\ClusterManifest.current.xml"
    $manConfig = [System.Xml.XmlDocument](Get-Content $manifestPath)
    $seedNode = $manConfig.ClusterManifest.Infrastructure.PaaS.Votes.Vote
    $nodeIpArray = $seedNode.IPAddressOrFQDN
    fixNodes -title "Seed Nodes" -scriptBlock $scriptBlock -nodeIpArray $nodeIpArray
}
else {
    fixNodes -title "Custom Nodes" -scriptBlock $scriptBlock -nodeIpArray $nodeIpArray
}

Write-host "Getting the list of all nodes" -foregroundcolor green
start-sleep -Seconds 60

Connect-ServiceFabricCluster
$node = Get-ServiceFabricNode
$nodeIpArray = $node.IpAddressOrFQDN 
Write-host "Fixing All Nodes" -foregroundcolor green

fixNodes -title "All Nodes" -scriptBlock $scriptBlock -nodeIpArray $nodeIpArray
write-host "reset trusted hosts to original values" -foregroundcolor green
set-item wsman:\localhost\Client\TrustedHosts -value $curValue -Force
Write-Progress -Completed -Activity "complete"

if ($global:successNodes) {
    $successUnique = $global:successNodes | sort-object -Unique
    write-host "total node success: $(@($successUnique).Count)" -ForegroundColor green
    write-host ($successUnique | fl * | out-string)
}
    
if ($global:failNodes) {
    $failUnique = $global:failNodes | sort-object -Unique
    write-warning "`r`ntotal node connection errors: $(@($failUnique).Count). review output"   
    write-host ($failUnique | fl * | out-string)
    write-warning "for any failed nodes, rdp to node and run this script with '-localOnly' switch"
}

write-host "finished. total minutes: $(((get-date) - $startTime).TotalMinutes.ToString("0.0"))" -foregroundcolor green

