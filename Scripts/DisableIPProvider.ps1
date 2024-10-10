#Requires -Version 3.0
# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.  All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# Feedback : pkc@microsoft.com
# ------------------------------------------------------------

<#
 .SYNOPSIS
    Update the Service Fabric Cluster to disable IPProviderEnabled settings
        Automating steps found in https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Cluster/unsupported-ipprovider.md

 .DESCRIPTION
    Script can be used to recover an unpatched Service Fabric cluster running > 6.3.63 with open networking enabled. 

 .PARAMETER nodeIpArray
    By default script will automatically grab the IP address for all the nodes

 .PARAMETER clusterDataRootPath
    Cluster data root path. default 'd:\svcfab'

 .PARAMETER tempPath
    Temporary path to store backup files. default 'd:\temp'

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
    [string]$tempPath = 'd:\temp',
    [switch]$cacheCredentials,
    [switch]$localOnly
)

$ErrorActionPreference = 'continue'
$supportedVersion = [version]"6.3.119.0"
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
} else {
    $currentVersion = [io.fileinfo]::new($defaultBinary).VersionInfo.FileVersion
}

#Verifying whether SF Runtime is at or above $supportedVersion
if ($currentVersion -lt $supportedVersion ) {
    write-warning "This Script is supported for the Service Fabric runtime version greater than $supportedVersion. 
        Please review external communication 
        'https://gist.github.com/athinanthny/f2191b93a3caea87446a73feacc66c79' 
        for clusters running version : $($SFEnv.FabricVersion )"
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
        . Updating Cluster Setting file with IPPE Parameter  
        #>

    function updateSettings {        
        param (
            [ValidateNotNullOrEmpty()]
            [parameter (Mandatory=$true, Position=0, ParameterSetName='settingsFileInfo')]
            [string]$SettingsFile
        )       

        Write-Host "$env:computername : Begin updating $SettingsFile"
        
        $xmlDoc = [System.Xml.XmlDocument](Get-Content $SettingsFile);
        $hosting = ($xmlDoc.Settings.Section | Where-Object -Property Name -EQ "Hosting").ChildNodes
        $ippeSetting = $hosting | Where-Object -Property Name -EQ "IPProviderEnabled"
        $ippeSetting.value = "$false"
        $xmlDoc.Save($settingsFile)
        
        Write-Host "$env:computername : Updated $SettingsFile sucessfully"
    }


    <#
        .SYNOPSIS
        . Add's a newline to end of file to trigger update of modified package config
    #>
    function addNewLine {        
        param (
            [ValidateNotNullOrEmpty()]
            [parameter (Mandatory=$true, Position=0, ParameterSetName='settingsFileInfo')]
            [string]$fileToModify
        )       

        Write-Host "$env:computername : Begin dummy update to $fileToModify"
               
        Add-Content $fileToModify "`n"
       
        Write-Host "$env:computername : Updated $fileToModify sucessfully"
    }

    #
    # Begin Script
    #
    
    $result = Get-ChildItem -Path $clusterDataRootPath -Filter "Fabric.Data" -Directory -Recurse
    $hostPath = $result.Parent.Parent.Name 
        
    Write-Host "---- Node Name  :  " $hostPath 
    Write-Host "---------------------------------------------------------------------------------------------------------"

    $settingsPath = ($clusterDataRootPath)
    Write-Host "$env:computername : Settings path: " $settingsPath

    # Validating whether Manifest file already contain IPProviderEnabled parameter with true                   
    [object]$tempIPPE = get-content ($settingsPath + '\FabricHostSettings.xml') | select-string -pattern '<Parameter Name="IPProviderEnabled" Value="true" />' -AllMatches
                
    If ($tempIPPE) {
        
        # create a temp folder
        $backupFolder = $tempPath + '\' + "backup" + $(get-date -f yyyy-MM-dd-HHmmss)
        $tempFolder = New-Item -ItemType Directory -Force -Path $backupFolder

        Write-Host "$env:computername : Created the backup folder :" $tempFolder

        # backup current config to the temp folder, append meta from where it came and when we made the backup
        $settingsFile = $settingsPath + '\FabricHostSettings.xml'
        Copy-Item -Path $settingsFile -Destination $backupFolder -Force -Verbose

        # appending cluster Settings File with IPProviderEnabled with value false
        updateSettings ($settingsPath + "\FabricHostSettings.xml")

        # add newline to Fabric.Package.current.xml to trigger update of modified settings
        $triggerUpdateFile = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Package.current.xml"
        addNewLine $triggerUpdateFile
    }
    else {
        Write-Host "No action required, the IPProviderEnabled parameter is not in use or has already been set = 'false' on: $env:computername"
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

Write-host "Waiting 60 seconds and then connecting to the cluster" -foregroundcolor green
Write-host "getting the list of all nodes" -foregroundcolor green
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
    write-warning "`r`ntotal node failed: $(@($failUnique).Count). review output"   
    write-host ($failUnique | fl * | out-string)
    write-warning "for any failed nodes, rdp to node and run this script with '-localOnly' switch"
}

write-host "finished. total minutes: $(((get-date) - $startTime).TotalMinutes.ToString("0.0"))" -foregroundcolor green
