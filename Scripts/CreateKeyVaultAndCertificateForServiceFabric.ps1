Param(
    [string] [Parameter(Mandatory=$true)] $SubscriptionId,
    [string] [Parameter(Mandatory=$true)] $Location,
    [string] [Parameter(Mandatory=$true)] $ResourceGroup,
    [string] [Parameter(Mandatory=$true)] $VaultName,
    [string] [Parameter(Mandatory=$true)] $CertificateName,
    [string] [Parameter(Mandatory=$true)] $CommonName
)

Set-StrictMode -Version 3

function Check-Session () {
    $Error.Clear()

    #if context already exist
    Get-AzureRmContext -ErrorAction Continue
    foreach ($eacherror in $Error) {
        if ($eacherror.Exception.ToString() -like "*Run Login-AzureRmAccount to login.*") {
            Login-AzureRmAccount
        }
    }

    $Error.Clear();
}

$ErrorActionPreference = "Stop"

Check-Session
Select-AzureRmSubscription -SubscriptionId $subscriptionId -ErrorAction Stop

New-AzureRmResourceGroup -Name $ResourceGroup -Location $location -Force

if(!(Get-AzureRmResource -ResourceName $VaultName -ResourceGroupName $ResourceGroup)) {
  New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroup  -Location $Location -EnabledForDeployment
}

$policy = New-AzureKeyVaultCertificatePolicy -DnsName $CommonName -IssuerName Self -ValidityInMonths 12
Add-AzureKeyVaultCertificate -VaultName $VaultName -Name $CertificateName -CertificatePolicy $policy

Write-Host "operation complete"