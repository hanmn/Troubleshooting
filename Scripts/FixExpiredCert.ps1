#Usage Instructions: Refer to https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/Fix%20Expired%20Cluster%20Certificate%20-%20Automated%20Script
Param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string] $clusterDataRootPath="D:\SvcFab",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$oldThumbprint="replace with expired thumbprint",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$newThumbprint="replace with new thumbprint",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$certStoreLocation='Cert:\LocalMachine\My\',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$nodeIpArray=@("10.0.0.4","10.0.0.5","10.0.0.6" )
)

Set-StrictMode -Version 3

$ErrorActionPreference = "Stop"

If(!(Test-Path $clusterDataRootPath))
{
    Write-Host $clusterDataRootPath " not found, exiting."
    Exit-PSSession
}

$curValue = (get-item wsman:\localhost\Client\TrustedHosts).value

Write-Host "Enter your RDP Credentials"
$creds = Get-Credential

ForEach($nodeIpAddress in $nodeIpArray)
{
    set-item wsman:\localhost\Client\TrustedHosts -value $nodeIpAddress -Force

    Start-Sleep(1)

    Invoke-Command -Authentication Negotiate -ComputerName $nodeIpAddress {
        Set-NetFirewallRule -DisplayGroup  'File and Printer Sharing' -Enabled True -PassThru |
        Select-Object DisplayName, Enabled
    } -Credential ($creds)

    Invoke-Command -Authentication Negotiate -Computername $nodeIpAddress -Scriptblock { param($clusterDataRootPath, $oldThumbprint, $newThumbprint, $certStoreLocation)
        Write-Host "Running on" (Get-WmiObject win32_computersystem).DNSHostName

        function StopServiceFabricServices
        {
            $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
            $fabricHost = "FabricHostSvc"

            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Running"){
                Stop-Service $bootstrapAgent
                Write-Host "Stopping " $bootstrapAgent " service"
            }
            Do
            {
                Start-Sleep -Seconds 1
                $bootstrapService = Get-Service -Name $bootstrapAgent
                if ($bootstrapService.Status -eq "Stopped"){
                    Write-Host $bootstrapAgent " now stopped"
                } else {
                    Write-Host $bootstrapAgent " current status:" $bootstrapService.Status
                }

            } While ($bootstrapService.Status -ne "Stopped")

            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Running"){
                Stop-Service $fabricHost
                Write-Host "Stopping " $fabricHost " service"
            }
            Do
            {
                Start-Sleep -Seconds 1
                $fabricHostService = Get-Service -Name $fabricHost
                if ($fabricHostService.Status -eq "Stopped"){
                    Write-Host $fabricHost " now stopped"
                } else {
                    Write-Host $fabricHost " current status:" $fabricHostService.Status
                }

            } While ($fabricHostService.Status -ne "Stopped")
        }

        function StartServiceFabricServices
        {
            $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
            $fabricHost = "FabricHostSvc"

            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Stopped"){
                Start-Service $fabricHost
                Write-Host "Starting" $fabricHost " service"
            }
            Do
            {
                Start-Sleep -Seconds 1
                $fabricHostService = Get-Service -Name $fabricHost
                if ($fabricHostService.Status -eq "Running"){
                    Write-Host $fabricHost " now running"
                } else {
                    Write-Host $fabricHost " current status:" $fabricHostService.Status
                }

            } While ($fabricHostService.Status -ne "Running")


            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Stopped"){
                Start-Service $bootstrapAgent
                Write-Host "Starting" $bootstrapAgent " service"
            }
            Do
            {
                Start-Sleep -Seconds 1
                $bootstrapService = Get-Service -Name $bootstrapAgent
                if ($bootstrapService.Status -eq "Running"){
                    Write-Host $bootstrapAgent " now running"
                } else {
                    Write-Host $bootstrapAgent " current status:" $bootstrapService.Status
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
        Write-Host "Settings file: " $SettingsFile
        Write-Host "Settings path: " $SettingsPath

        $settings = [xml](Get-Content $SettingsFile)

        #TODO: validate newThumbprint is installed
        $thumbprintPath = $certStoreLocation + $newThumbprint
        If(!(Test-Path $thumbprintPath))
        {
            Write-Host $newThumbprint "not installed"
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
        Write-Host "Setting ACL for" $thumbprint

        #get the container name
        $cert = get-item $thumbprint
        $uniqueKeyContainerName = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName

        # Specify the user, the permissions and the permission type
        $permission = "$("NETWORK SERVICE")","FullControl","Allow"
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
        get-acl $keyFullPath| Format-List
        #------------------------------------------------------- done ACL

        # create a temp folder
        New-Item -ItemType Directory -Force -Path 'd:\temp\certwork'

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
        Write-Host "Stopping services "
        StopServiceFabricServices

        #update the node configuration
        $logRoot = $clusterDataRootPath + "\Log"
        Write-Host "Updating Node configuration with new cert:" $newThumbprint
        New-ServiceFabricNodeConfiguration -FabricDataRoot $clusterDataRootPath -FabricLogRoot $logRoot -ClusterManifestPath $newManifest -InfrastructureManifestPath $newInfraManifest
        Write-Host "Updating Node configuration with new cert: complete"

        #restart these services
        Write-Host "Starting services "
        StartServiceFabricServices
    } -ArgumentList $clusterDataRootPath, $oldThumbprint, $newThumbprint, $certStoreLocation
}

#reset trusted hosts to original values
set-item wsman:\localhost\Client\TrustedHosts -value $curValue -Force