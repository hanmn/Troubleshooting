Swap Primary and Secondary certificates
=======================================

MSDN Reference

<https://azure.microsoft.com/en-us/documentation/articles/service-fabric-cluster-security-update-certs-azure/#add-a-secondary-certificate-and-swap-it-to-be-the-primary-using-resource-manager-powershell> 

<https://github.com/ChackDan/Service-Fabric/tree/master/ARM%20Templates/Cert%20Rollover%20Sample> (diff and you will see the differences)


## Steps

1.  Create new cert using [CreateKeyVaultAndCertificateForServiceFabric.ps1](./CreateKeyVaultAndCertificateForServiceFabric.ps1)

	a.  If you use [Add new cert to VMSS](./Add_New_Cert_To_VMSS.ps1) to deploy your new certificate to the VMMS, and the new certificate was added to the same key vault your primary cert was in, then you may see this error because the PowerShell script is trying to add a duplicate "sourceVault" to the list of secrets on the VMMS resource.

![Update-AzureRmVmss List secrets contains repeated instances of /subscriptions/{redacted}/resourceGroups/{redacted}/... which is disallowed
StatusCode: 400
Reasonphrase: Bad Request](../media/certswap_image1.png)

>>b.  You can work-around this two ways
>>* Create the new cert in a different keyvault.
>>* See steps 4a - 4b on [Use Azure Resource Explorer to add the Secondary Certificate.md](./Use%20Azure%20Resource%20Explorer%20to%20add%20the%20Secondary%20Certificate.md)

2.  *(optional)* Change Advanced Upgrade Settings to use shorter times, which speeds up the cert add and swap operations significantly.  Older cluster may have 00:05:00 minute wait durations which cause this process to be much slower than desired.

```Batch
Health check retry timeout - set to 00:02:00
Health check wait duration - set to 00:00:30
Health check stable duration - set to 00:00:30  
```

3.  Add new Cert thumbprint in Secondary Certificate slot

    From PowerShell run [Add-AzureRmServiceFabricClusterCertificate](https://docs.microsoft.com/en-us/powershell/module/azurerm.servicefabric/Add-AzureRmServiceFabricClusterCertificate?view=azurermps-4.1.0)

```PowerShell
Add-AzureRmServiceFabricClusterCertificate -ResourceGroupName 'Group1' -Name 'Contoso01SFCluster' -SecretIdentifier '<https://contoso03vault.vault.azure.net/secrets/contoso03vaultrg/7f7de9131c034172b9df37ccc549524f>'
```

4.  Swap cert in Portal
	
* Azure Portal -> ResourceGroup -> Cluster -> Security
	* Select the Secondary certificate
	* Click ellipse ( ... ) and pick **Swap with Primary**


**NOTE:** Starting with Service Fabric 5.7, only the cert with the farthest expiration date can be used for authentication unless modifying setting UseSecondaryIfNewer in manifest. Once a new cert has been added to environment regardless if secondary or primary, only the newer cert will be used (assuming the new cert expiration date is further than existing cert) **


5.  Delete old cert from Portal (now secondary)

* Azure Portal -> ResourceGroup -> Cluster -> Security
	* Select the Secondary certificate
	* Click ellipse ( ... ) and pick **Delete** 

or

From PowerShell run [Remove-AzureRmServiceFabricClusterCertificate](https://docs.microsoft.com/en-us/powershell/module/azurerm.servicefabric/Remove-AzureRmServiceFabricClusterCertificate)

```PowerShell
Remove-AzureRmServiceFabricClusterCertificate -ResourceGroupName 'Group1' -Name 'Contoso01SFCluster' -Thumbprint '5F3660C715EBBDA31DB1FFDCF508302348DE8E7A
```

6.  (optional) Change Advanced Upgrade Settings back to use original healthcheck times

```Batch
Health check retry timeout - set to 00:45:00
Health check wait duration - set to 00:05:00
Health check stable duration - set to 00:05:00
```

