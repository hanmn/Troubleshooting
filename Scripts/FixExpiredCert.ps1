<#

.SYNOPSIS
    Script to attempt to replace expired certificate on service fabric cluster

.DESCRIPTION
    Usage Instructions: Refer to https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/Fix%20Expired%20Cluster%20Certificate%20-%20Automated%20Script

.PARAMETER clusterDataRootPath
    service fabric data installation path. default d:\svcfab in azure

.PARAMETER oldThumbPrint
    [required][string] old / expired existing certificate thumbprint that needs to be replaced

.PARAMETER newThumbPrint
    [required][string] new / valid certificate thumbprint for cluster

.PARAMETER certStoreLocation
    [string]default certificate store location 'Cert:\LocalMachine\My\',

.PARAMETER nodeIpArray
    [string[]] string array of ip addresses of nodes in cluster

.PARAMETER cacheCredentials
    [switch] enable storing credentials in $global:creds variable.
    to clear, execute: $global:creds=$null

.PARAMETER localOnly
    switch to optionally run script only on local node.
    use when there are connectivity issues between nodes by rdp'ing to each node and running with this switch.

.LINK
    iwr https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/FixExpiredCert.ps1 -out $pwd/FixExpiredCert.ps1
#>

Param(
    [ValidateNotNullOrEmpty()]
    [string] $clusterDataRootPath = "D:\SvcFab",
    [ValidateNotNullOrEmpty()]
    [string]$oldThumbprint = "replace with expired thumbprint",
    [ValidateNotNullOrEmpty()]
    [string]$newThumbprint = "replace with new thumbprint",
    [ValidateNotNullOrEmpty()]
    [string]$certStoreLocation = 'Cert:\LocalMachine\My\',
    [ValidateNotNullOrEmpty()]
    [string[]]$nodeIpArray = @("10.0.0.4", "10.0.0.5", "10.0.0.6" ),
    [switch]$cacheCredentials,
    [switch]$localOnly
)

$error.Clear()
$ErrorActionPreference = 'continue'
$startTime = get-date
$global:failNodes = @()
$global:successNodes = @()
$count = 0
$creds = $null

If (!(Test-Path $clusterDataRootPath)) {
    Write-Host $clusterDataRootPath " not found, exiting."
    return
}

$curValue = (get-item wsman:\localhost\Client\TrustedHosts).value

if (!$global:creds) {
    Write-Host "Enter your RDP Credentials"

    #Get the RDP User Name and Password
    $creds = Get-Credential

    if ($cacheCredentials) {
        $global:creds = $creds
    }
}

if (![regex]::IsMatch($oldThumbprint, '^[0-9A-Fa-f]{24,}$') -or ![regex]::IsMatch($newThumbprint, '^[0-9A-Fa-f]{24,}$')) {
    write-warning "verify oldthumbprint:($oldthumbprint) and newthumbprint:($newthumbprint) are specified and are correct."
    #return
}

$scriptBlock = { param($clusterDataRootPath, $oldThumbprint, $newThumbprint, $certStoreLocation)
    Write-Host "$env:computername : Running on $((Get-WmiObject win32_computersystem).DNSHostName)" -ForegroundColor Green

    function StopServiceFabricServices {
        if ($(Get-Process | ? ProcessName -like "*FabricInstaller*" | measure).Count -gt 0) {
            Write-Warning "$env:computername : Found FabricInstaller running, may cause issues if not stopped, consult manual guide..."
            Write-Host "$env:computername : Pausing (15s)..." -ForegroundColor Green
            Start-Sleep -Seconds 15
        }

        $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
        $fabricHost = "FabricHostSvc"

        $bootstrapService = Get-Service -Name $bootstrapAgent
        if ($bootstrapService.Status -eq "Running") {
            Stop-Service $bootstrapAgent -ErrorAction SilentlyContinue 
            Write-Host "$env:computername : Stopping $bootstrapAgent service" -ForegroundColor Green
        }
        Do {
            Start-Sleep -Seconds 1
            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Stopped") {
                Write-Host "$env:computername : $bootstrapAgent now stopped" -ForegroundColor Green
            }
            else {
                Write-Host "$env:computername : $bootstrapAgent current status: $($bootstrapService.Status)" -ForegroundColor Green
            }

        } While ($bootstrapService.Status -ne "Stopped")

        $fabricHostService = Get-Service -Name $fabricHost
        if ($fabricHostService.Status -eq "Running") {
            Stop-Service $fabricHost -ErrorAction SilentlyContinue 
            Write-Host "$env:computername : Stopping $fabricHost service" -ForegroundColor Green
        }
        Do {
            Start-Sleep -Seconds 1
            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Stopped") {
                Write-Host "$env:computername : $fabricHost now stopped" -ForegroundColor Green
            }
            else {
                Write-Host "$env:computername : $fabricHost current status: $($fabricHostService.Status)" -ForegroundColor Green
            }

        } While ($fabricHostService.Status -ne "Stopped")
    }

    function StartServiceFabricServices {
        $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
        $fabricHost = "FabricHostSvc"

        $fabricHostService = Get-Service -Name $fabricHost
        if ($fabricHostService.Status -eq "Stopped") {
            Start-Service $fabricHost -ErrorAction SilentlyContinue 
            Write-Host "$env:computername : Starting $fabricHost service" -ForegroundColor Green
        }
        Do {
            Start-Sleep -Seconds 1
            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Running") {
                Write-Host "$env:computername : $fabricHost now running" -ForegroundColor Green
            }
            else {
                Write-Host "$env:computername : $fabricHost current status: $($fabricHostService.Status)" -ForegroundColor Green
            }

        } While ($fabricHostService.Status -ne "Running")


        $bootstrapService = Get-Service -Name $bootstrapAgent
        if ($bootstrapService.Status -eq "Stopped") {
            Start-Service $bootstrapAgent -ErrorAction SilentlyContinue 
            Write-Host "$env:computername : Starting $bootstrapAgent service" -ForegroundColor Green
        }
        Do {
            Start-Sleep -Seconds 1
            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Running") {
                Write-Host "$env:computername : $bootstrapAgent now running" -ForegroundColor Green
            }
            else {
                Write-Host "$env:computername : $bootstrapAgent current status: $($bootstrapService.Status)" -ForegroundColor Green
            }

        } While ($bootstrapService.Status -ne "Running")
    }

    #config files we need
    #"D:\SvcFab\clusterManifest.xml"
    #"D:\SvcFab\_sys_0\Fabric\Fabric.Data\InfrastructureManifest.xml"
    #"D:\SvcFab\_sys_0\Fabric\Fabric.Config.1.131523081591497214\Settings.xml"

    $result = Get-ChildItem -Path $clusterDataRootPath -Filter "Fabric.Data" -Directory -Recurse
    $hostPath = $result.Parent.Parent.Name
    Write-Host "---------------------------------------------------------------------------------------------------------"
    Write-Host "---- Working on ip:" $hostPath
    Write-Host "---------------------------------------------------------------------------------------------------------"

    $manifestPath = $clusterDataRootPath + "\" + $hostPath + "\Fabric\ClusterManifest.current.xml"

    $currentPackage = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Package.current.xml"
    $infrastructureManifest = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Data\InfrastructureManifest.xml"

    #to get the settings.xml we need to determine the current version
    #"D:\SvcFab\_sys_0\Fabric\Fabric.Package.current.xml" --> Read to determine verion# <ConfigPackage Name="Fabric.Config" Version="1.131523081591497214" />
    $currentPackageXml = [xml](Get-Content $currentPackage)
    $packageName = $currentPackageXml.ServicePackage.DigestedConfigPackage.ConfigPackage | Select-Object -ExpandProperty Name
    $packageVersion = $currentPackageXml.ServicePackage.DigestedConfigPackage.ConfigPackage | Select-Object -ExpandProperty Version
    $SettingsFile = $clusterDataRootPath + "\" + $hostPath + "\Fabric\" + $packageName + "." + $packageVersion + "\settings.xml"
    $SettingsPath = $clusterDataRootPath + "\" + $hostPath + "\Fabric\" + $packageName + "." + $packageVersion
    Write-Host "$env:computername : settings file: " $SettingsFile
    Write-Host "$env:computername : Settings path: " $SettingsPath

    $settings = [xml](Get-Content $SettingsFile)

    #TODO: validate newThumbprint is installed
    $thumbprintPath = $certStoreLocation + $newThumbprint
    If (!(Test-Path $thumbprintPath)) {
        Write-Host "$env:computername : $newThumbprint not installed"
        Exit-PSSession
    }

    #TODO: validate newThumbprint is ACL'd for NETWORK_SERVICE
    #------------------------------------------------------- start ACL
    #Change to the location of the local machine certificates
    $currentLocation = Get-Location
    Set-Location $certStoreLocation

    #display list of installed certificates in this store
    Get-ChildItem | Format-Table Subject, Thumbprint, SerialNumber -AutoSize
    Set-Location $currentLocation

    $thumbprint = $certStoreLocation + "\" + $newThumbprint
    Write-Host "$env:computername : Setting ACL for $thumbprint" -ForegroundColor Green

    #get the container name
    $cert = get-item $thumbprint

    # Specify the user, the permissions and the permission type
    $permission = "$("NETWORK SERVICE")", "FullControl", "Allow"
    $accessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $permission

    # Location of the machine related keys
    $keyPath = Join-Path -Path $env:ProgramData -ChildPath "\Microsoft\Crypto\RSA\MachineKeys"
    $keyName = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
    $keyFullPath = Join-Path -Path $keyPath -ChildPath $keyName

    # Get the current acl of the private key
    $acl = (Get-Item $keyFullPath).GetAccessControl('Access')

    # Add the new ace to the acl of the private key
    $acl.SetAccessRule($accessRule)

    # Write back the new acl
    Set-Acl -Path $keyFullPath -AclObject $acl -ErrorAction Stop

    # Observe the access rights currently assigned to this certificate.
    get-acl $keyFullPath | Format-List
    #------------------------------------------------------- done ACL

    # create a temp folder
    New-Item -ItemType Directory -Force -Path 'd:\temp\certwork' | out-null

    #copy current config to the temp folder
    Copy-Item -Path $manifestPath -Destination 'd:\temp\certwork' -Force -Verbose
    $newManifest = "D:\temp\certwork\modified_clustermanifest.xml"
    Copy-Item -Path $infrastructureManifest -Destination 'd:\temp\certwork' -Force -Verbose
    $newInfraManifest = "D:\temp\certwork\modified_InfrastructureManifest.xml"
    Copy-Item -Path $SettingsFile -Destination 'd:\temp\certwork' -Force -Verbose
    $newSettingsManifest = "D:\temp\certwork\modified_settings.xml"

    # find and replace old thumbprint with the new one
    (Get-Content "d:\temp\certwork\clustermanifest.current.xml" |
        Foreach-Object { $_ -replace $oldThumbprint, $newThumbprint } |
        Set-Content $newManifest)

    # find and replace old thumbprint with the new one
    (Get-Content "d:\temp\certwork\InfrastructureManifest.xml" |
        Foreach-Object { $_ -replace $oldThumbprint, $newThumbprint } |
        Set-Content $newInfraManifest)

    # find and replace old thumbprint with the new one
    (Get-Content "d:\temp\certwork\settings.xml" |
        Foreach-Object { $_ -replace $oldThumbprint, $newThumbprint } |
        Set-Content $newSettingsManifest)

    $backupSettingsFile = $SettingsPath + "\settings_backup.xml"
    Copy-Item -Path $SettingsFile -Destination $backupSettingsFile -Force -Verbose
    Copy-Item -Path $newSettingsManifest -Destination $SettingsFile -Force -Verbose

    #stop these services
    Write-Host "$env:computername : Stopping services " -ForegroundColor Green
    StopServiceFabricServices

    #update the node configuration
    $logRoot = $clusterDataRootPath + "\Log"
    Write-Host "$env:computername : Updating Node configuration with new cert: $newThumbprint" -ForegroundColor Green
    New-ServiceFabricNodeConfiguration -FabricDataRoot $clusterDataRootPath -FabricLogRoot $logRoot -ClusterManifestPath $newManifest -InfrastructureManifestPath $newInfraManifest
    Write-Host "$env:computername : Updating Node configuration with new cert: complete" -ForegroundColor Green

    #restart these services
    Write-Host "$env:computername : Starting services " -ForegroundColor Green
    StartServiceFabricServices
}

if ($localOnly) {
    write-host "executing on local node only"
    invoke-command -ScriptBlock $scriptBlock -ArgumentList $clusterDataRootPath, $oldThumbprint, $newThumbprint, $certStoreLocation
    return
}

ForEach ($nodeIpAddress in $nodeIpArray) {
    $count++
    #Verifying whether corresponding VM is up and running
    if (Test-Connection -ComputerName $nodeIpAddress -Quiet) {
     
        $activity = "total minutes: $(((get-date) - $startTime).TotalMinutes.tostring("0.0")). connecting to: $nodeIpAddress  ($count of $($nodeIpArray.Count))"
        $status = "success: $($global:successNodes | sort -Unique) fail: $($global:failNodes | sort -Unique)"
        Write-Progress -Activity $activity `
            -Status $status `
            -PercentComplete (($count / $nodeIpArray.Count) * 100)

        write-host "$env:computername : updating trustedhosts list" -foregroundcolor green
        set-item wsman:\localhost\Client\TrustedHosts -value $nodeIpAddress -Force

        Start-Sleep(1)

        $error.clear()
        Invoke-Command -Authentication Negotiate -ComputerName $nodeIpAddress {
            Set-NetFirewallRule -DisplayGroup  'File and Printer Sharing' -Enabled True -PassThru |
            Select-Object DisplayName, Enabled
        } -Credential ($creds)

        if ($error) {
            $global:failNodes += $nodeIpAddress
            continue
        }

        $error.clear()
        Invoke-Command -Authentication Negotiate -Computername $nodeIpAddress -Scriptblock $scriptBlock `
            -ArgumentList $clusterDataRootPath, $oldThumbprint, $newThumbprint, $certStoreLocation
        
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