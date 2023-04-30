#Requires -Version 3.0
# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.  All rights reserved.
# Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# Feedback : pkc@microsoft.com
# ------------------------------------------------------------

<#
 .SYNOPSIS
    Updates the private key ACL to give NETWORK SERVICE full access for the specified thumbprint

 .DESCRIPTION
    Updates the private key ACL to give NETWORK SERVICE full access for the specified thumbprint

 .PARAMETER thumbprint 
     A temporary working folder to copy and work with Cluster Manifest and Settings files

#>
Param(
    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()]
    [string]$thumbprint = "745d76f35990264359a650331054d784e293f1d4" 
)
Set-StrictMode -Version 3
$ErrorActionPreference = "Stop"

#Saving current list of Trusted Hosts
$curValue = (get-item wsman:\localhost\Client\TrustedHosts).value

Write-Host "Enter your RDP Credentials"

#Get the RDP User Name and Password
$creds = Get-Credential

function fixNodes
{
    ForEach($nodeIpAddress in $nodeIpArray)
        {
             #Verifying whether corresponding VM is up and running
            if (Test-Connection -ComputerName $nodeIpAddress -Quiet) 
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

                Invoke-Command -Authentication Negotiate -Computername $nodeIpAddress -Scriptblock { param($thumbprint)
                    # Local Machine certificate store
                    $certStoreLocation='Cert:\LocalMachine\My'

                    <#
                    .SYNOPSIS
                    . Updating Private Key permissions for $thumbprint
                    #>

                    function UpdateThumbprintPermissions 
                    {            
                        Write-Host "Begin updating ClusterManifest.xml File"
                        
                        #Change to the location of the local machine certificates
                        $currentLocation = Get-Location
                        Set-Location $certStoreLocation

                        #display list of installed certificates in this store
                        Get-ChildItem | Format-Table Subject, Thumbprint, SerialNumber -AutoSize
                        Set-Location $currentLocation

                        $FullyQualifiedThumbprint = $certStoreLocation + "\" + $thumbprint
                        Write-Host "Setting ACL for" $FullyQualifiedThumbprint         

                        #get the container name
                        $cert = get-item $FullyQualifiedThumbprint 
                        $uniqueKeyContainerName = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
                                # Specify the user, the permissions and the permission type                        $permission = "$("NETWORK SERVICE")","FullControl","Allow"                        $accessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $permission
                                # Location of the machine related keys                        $keyPath = Join-Path -Path $env:ProgramData -ChildPath "\Microsoft\Crypto\RSA\MachineKeys"                        $keyName = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName                        $keyFullPath = Join-Path -Path $keyPath -ChildPath $keyName
                                # Get the current acl of the private key                        $acl = (Get-Item $keyFullPath).GetAccessControl('Access')
                                # Add the new ace to the acl of the private key                        $acl.SetAccessRule($accessRule)
                                # Write back the new acl                        Set-Acl -Path $keyFullPath -AclObject $acl -ErrorAction Stop
                                # Observe the access rights currently assigned to this certificate.                        get-acl $keyFullPath| fl 
                            
                        Write-Host "Updated ACL for : " $FullyQualifiedThumbprint 
                    
                    }
                    
                    UpdateThumbprintPermissions
                   
                   
                } -ArgumentList $thumbprint
           }
        }

}

start-sleep -Seconds 5

Connect-ServiceFabricCluster
$node = Get-ServiceFabricNode
$nodeIpArray = $node.IpAddressOrFQDN 

fixNodes

Write-host "Done..."
 
#reset trusted hosts to original values
set-item wsman:\localhost\Client\TrustedHosts -value $curValue -Force
