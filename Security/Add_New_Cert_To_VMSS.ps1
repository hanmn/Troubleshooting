# [AzureRM.ServiceFabric module], latest available @ https://www.powershellgallery.com/packages/AzureRM.ServiceFabric/0.3.8
#
#These new PowerShell commands are the preferred method to add/remove or manage certificates in the cluster
#    Cmdlet          Add-AzureRmServiceFabricApplicationCertificate     0.2.0      AzureRM.ServiceFabric 
#    Cmdlet          Add-AzureRmServiceFabricClientCertificate          0.2.0      AzureRM.ServiceFabric 
#    Cmdlet          Add-AzureRmServiceFabricClusterCertificate         0.2.0      AzureRM.ServiceFabric 
#    Cmdlet          Remove-AzureRmServiceFabricClientCertificate       0.2.0      AzureRM.ServiceFabric 
#    Cmdlet          Remove-AzureRmServiceFabricClusterCertificate      0.2.0      AzureRM.ServiceFabric 
#
#
#The following is a PowerShell Script to Achieve this:
#
# For Windows Cluster this script should run as-is
# For Linux Clusters, remove -CertificateStore "My" parameter from New-AzureRmVmssVaultCertificateConfig function
#
# Certificate Configuration
# Couldn't add or renew certificate

Param(
    [string] [Parameter(Mandatory=$true)] $KeyVaultResourceGroupName,
    [string] [Parameter(Mandatory=$true)] $VmssResourceGroupName,
    [string] [Parameter(Mandatory=$true)] $VaultName,
    [string] [Parameter(Mandatory=$true)] $VmssName,
    [string] [Parameter(Mandatory=$true)] $SubscriptionId
    ,[string] [Parameter(Mandatory=$true)] $CertificateUrl
)

Set-StrictMode -Version 3

$ErrorActionPreference = "Stop"

# Login
Login-AzureRmAccount -SubscriptionId $SubscriptionId
$sourceVaultId = "/subscriptions/$SubscriptionId/resourceGroups/$KeyVaultResourceGroupName/providers/Microsoft.KeyVault/vaults/$VaultName"
$sourceVaultId
$certConfig = New-AzureRmVmssVaultCertificateConfig -CertificateUrl $CertificateUrl -CertificateStore "My"
$certConfig
# Get current vmss
$vmss = Get-AzureRmVmss -ResourceGroupName $VmssResourceGroupName -VMScaleSetName $VmssName
$vmss
# add new secret
$vmss = Add-AzureRmVmssSecret -VirtualMachineScaleSet $vmss -SourceVaultId $sourceVaultId -VaultCertificate $certConfig
$vmss
# update VMSS
Update-AzureRmVmss -ResourceGroupName $VmssResourceGroupName -Name $VmssName -VirtualMachineScaleSet $vmss -Verbose
