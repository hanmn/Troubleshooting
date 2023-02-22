#Requires -Version 3.0
# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.  All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

<#
 .SYNOPSIS
    Fix the Service Fabric Cluster with Expired Certificate (Self Signed

 .DESCRIPTION
    Script can be used to recover the Service Fabric cluster with expired certificate. 

 .PARAMETER nodeIpArray
    By default script will automatically take all the IP address for seed node, For patching non-primary node type need provide the IP address for all the node.

  .PARAMETER tempPath
     A temporary working folder to copy and work with Cluster Manifest and Settings files

#>
Param(
    [Parameter(Mandatory=$false)] #$true
    [ValidateNotNullOrEmpty()]
    [string[]] $nodeIpArray =@("0"),

    [Parameter(Mandatory=$false)] #$true
    [ValidateNotNullOrEmpty()]
    [string]$tempPath = "d:\temp\certwork" 
    
)
Set-StrictMode -Version 3
$ErrorActionPreference = "Stop"

 <#
.SYNOPSIS
    Get the SF Cluster Data Root from Registry    
#>
 $SFEnv = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Service Fabric" 
 $clusterDataRootPath = $SFEnv.FabricDataRoot
 $supportedVersion ="6.5.658.9590"
 

if ($SFEnv.FabricVersion -gt $supportedVersion )
{

    If(!(Test-Path $clusterDataRootPath))
    {
    Write-Host $clusterDataRootPath " not found, exiting."
    Exit-PSSession
    }

    #Saving current list of Trusted Hosts
    $curValue = (get-item wsman:\localhost\Client\TrustedHosts).value

    Write-Host "Enter your RDP Credentials"

    #Get the RDP User Name and Password
    $creds = Get-Credential

    <#
    .SYNOPSIS
    Get the list of seed nodes
    Todo : Find the way to get the details of all the ip's of node under the scaleset
    #>

    if ($nodeIpArray[0] -eq 0 )
                                {
    Write-Host ("Getting  Seed node details") 
    $result = Get-ChildItem -Path $clusterDataRootPath -Filter "Fabric.Data" -Directory -Recurse
    $hostPath = $result.Parent.Parent.Name 
    $manifestPath = $clusterDataRootPath + "\" + $hostPath + "\Fabric\ClusterManifest.current.xml"
    $manConfig = [System.Xml.XmlDocument](Get-Content $manifestPath)
    $seedNode  = $manConfig.ClusterManifest.Infrastructure.PaaS.Votes.Vote
    $nodeIpArray = $seedNode.IPAddressOrFQDN
    }

    <#
    .SYNOPSIS
    . Run the script in each node
    #>

    ForEach($nodeIpAddress in $nodeIpArray)
{
       
    set-item wsman:\localhost\Client\TrustedHosts -value $nodeIpAddress -Force   
    Write-Host "---------------------------------------------------------------------------------------------------------"
    Write-Host "---- Node IP    :" $nodeIpAddress
    
    Start-Sleep(1)

    Invoke-Command -Authentication Negotiate -ComputerName $nodeIpAddress {
       $temp = Set-NetFirewallRule -DisplayGroup  'File and Printer Sharing' -Enabled True -PassThru |
        Select-Object DisplayName, Enabled
    } -Credential ($creds)
 
    #******************************************************************************
    # Script body
    # Execution begins here
    #******************************************************************************

    Invoke-Command -Authentication Negotiate -Computername $nodeIpAddress -Scriptblock { param($clusterDataRootPath,$tempPath)
        
        <#
          .SYNOPSIS
          . Updating Cluster Manifest file with AEPCC Parameter  
         #>

        function updateManifest 
        {            
            Write-Host "Begin updating ClusterManifest.xml File"
            $manFile = $tempPath + "\clustermanifest.current.xml"
            $newManifest = $tempPath + "\modified_clustermanifest.xml"

            $ModContent = Get-Content -Path $manFile |
             ForEach-Object {
                 # Output the existing line to pipeline in any case
                 $_
            
                 if($_ -match '<Section Name="Security">' )
                 {
                    '      <Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="true" />'
                 }
               }
  
            $ModContent | Out-File -FilePath $newManifest -Encoding Default -Force           
            Write-Host "Updated the ClusterManifest.xml File : " $newManifest 
           
        }
        <#
          .SYNOPSIS
          . Updating Cluster Setting file with AEPCC Parameter  

         #>

        function updateSettings
        {       
          Write-Host "Begin updating Settings.xml File"
          $settingFile = $tempPath + "\Settings.xml"
          $newSettings = $tempPath + "\modified_settings.xml"

          #validating the existence of AEPCC Parameter

          $SettingConfig = [System.Xml.XmlDocument] (Get-Content $settingFile)
          $SecSettingConfig = $tempSettingConfig.Settings.Section | where {$_.Name -eq "Security"}
                    
            If ($SecSettingConfig.Parameter.Name -notcontains "AcceptExpiredPinnedClusterCertificate")
            {
                 $ModContent = Get-Content -Path $settingFile |
                 ForEach-Object {             
                     $_
       
                     if($_ -match '<Section Name="Security">' )
                     {
                        '    <Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="true" />'
                     }
                   }
               
                $ModContent | Out-File -FilePath $newSettings -Encoding Default -Force
                Write-Host "Updated Settings.xml " $newSettings
            }
            else
            {
                Copy-Item -Path $settingFile -Destination $newSettings  -Force -Verbose
                write-host " Already contain AEPCC parameter"
            }                 

        }
        <#
          .SYNOPSIS
          . Stopping both SFNBA and FabricHost

         #>
        function StopServiceFabricServices
        {
            $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
            $fabricHost = "FabricHostSvc"

            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Running"){
                Stop-Service $bootstrapAgent -ErrorAction SilentlyContinue
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
                Stop-Service $fabricHost -ErrorAction SilentlyContinue
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
        <#
          .SYNOPSIS
          . Starting both SFNBA and FabricHost
         #>

        function StartServiceFabricServices
        {
            $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
            $fabricHost = "FabricHostSvc"

            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Stopped"){
                Start-Service $fabricHost -ErrorAction SilentlyContinue
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
                Start-Service $bootstrapAgent -ErrorAction SilentlyContinue
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
        #"D:\SvcFab\ClusterManifest.current.xml"
        #"D:\SvcFab\_sys_0\Fabric\Fabric.Config.<highest version> \Settings.xml"

        $result = Get-ChildItem -Path $clusterDataRootPath -Filter "Fabric.Data" -Directory -Recurse
        $hostPath = $result.Parent.Parent.Name 
        
        Write-Host "---- Node Name  :  " $hostPath 
        Write-Host "---------------------------------------------------------------------------------------------------------"

        $manifestPath = $clusterDataRootPath + "\" + $hostPath + "\Fabric\ClusterManifest.current.xml"
        $currentPackage = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Package.current.xml"
        $infrastructureManifest = $clusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Data\InfrastructureManifest.xml"
        
        #  For Validating whether Manifest file already contain AEPCC parameter. 
         $manConfig = [System.Xml.XmlDocument] (Get-Content $manifestPath)
         $manSecConfig = $manConfig.ClusterManifest.FabricSettings.Section | where {$_.Name -eq "Security"}
         
         If ($manSecConfig.Parameter.Name  -notcontains "AcceptExpiredPinnedClusterCertificate")
            {
                #to get the settings.xml we need to determine the current version
                #"D:\SvcFab\_sys_0\Fabric\Fabric.Package.current.xml" --> Read to determine version# <ConfigPackage Name="Fabric.Config" Version="1.131523081591497214" />
                $currentPackageXml = [xml](Get-Content $currentPackage)
                $packageName = $currentPackageXml.ServicePackage.DigestedConfigPackage.ConfigPackage | Select-Object -ExpandProperty Name
                $packageVersion = $currentPackageXml.ServicePackage.DigestedConfigPackage.ConfigPackage | Select-Object -ExpandProperty Version
                $SettingsFile = $clusterDataRootPath + "\" + $hostPath + "\Fabric\" + $packageName + "." + $packageVersion + "\settings.xml"
                $SettingsPath = $clusterDataRootPath + "\" + $hostPath + "\Fabric\" + $packageName + "." + $packageVersion
                Write-Host "Settings file: " $SettingsFile       
                Write-Host "Settings path: " $SettingsPath 

                # create a temp folder
                $tempFolder = New-Item -ItemType Directory -Force -Path $tempPath 

                Write-Host "Created the temp Work folder :" $tempFolder

                #copy current config to the temp folder
                Copy-Item -Path $manifestPath -Destination $tempPath -Force -Verbose
                $newManifest = $tempPath + "\modified_clustermanifest.xml"
                Copy-Item -Path $SettingsFile -Destination $tempPath -Force -Verbose
                $newSettingsManifest = $tempPath + "\modified_settings.xml"            

                # Appending cluster manifest with AcceptExpiredPinnedClusterCertificate
                updateManifest
                              
                # Appending cluster manifest with AcceptExpiredPinnedClusterCertificate
                updateSettings
               
                ### Backup.... 
                $backupSettingsFile = $SettingsPath + "\settings_backup.xml"
                Copy-Item -Path $SettingsFile -Destination $backupSettingsFile -Force -Verbose
                Copy-Item -Path $newSettingsManifest -Destination $SettingsFile -Force -Verbose

                #stop these services
                Write-Host "Stopping services "
                StopServiceFabricServices

                #update the node configuration
                $logRoot = $clusterDataRootPath + "\Log"
                Write-Host "Updating Node configuration with new setting AcceptExpiredPinnedClusterCertificate " 
        
                #For Debugging 
                Write-Host "Cluster Manifest " $newManifest
                Write-Host " Log Root" $logRoot 
                Write-Host "Cluster Data Path  : "$clusterDataRootPath 
                Write-Host "Infra :" $infrastructureManifest
         
                New-ServiceFabricNodeConfiguration -FabricDataRoot $clusterDataRootPath -FabricLogRoot $logRoot -ClusterManifestPath $newManifest -InfrastructureManifestPath $infrastructureManifest 
                Write-Host "Updating Node configuration  complete"

                #restart these services
                Write-Host "Starting services "
                StartServiceFabricServices
          }
          else
          {
               Write-Host ("Manifest File already contain the AEPCC parameter" + $nodeIpAddress)                    
          }
    } -ArgumentList $clusterDataRootPath,$tempPath
    }

    #reset trusted hosts to original values
    set-item wsman:\localhost\Client\TrustedHosts -value $curValue -Force
}
else 
{
   Write-Host "This Script is supported for the Service Fabric runtime version greater than $supportedVersion. Please leverage external TSG 'https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/Fix%20Expired%20Cluster%20Certificate%20Automated%20Script.md' for fixing the issue with : "  $SFEnv.FabricVersion 
}
