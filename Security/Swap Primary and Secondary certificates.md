Swap Primary and Secondary certificates
=======================================

<https://github.com/Azure/service-fabric-issues/issues/31> (For reference)

<https://azure.microsoft.com/en-us/documentation/articles/service-fabric-cluster-security-update-certs-azure/#add-a-secondary-certificate-and-swap-it-to-be-the-primary-using-resource-manager-powershell> (PG is still working to fix some issues on this documentation but the templates referenced on the article are right)

<https://github.com/ChackDan/Service-Fabric/tree/master/ARM%20Templates/Cert%20Rollover%20Sample> (diff and you will see the differences)


## Steps

1.  Create new cert in different KeyVault using [CreateKeyVaultAndCertificateForServiceFabric.ps1](./CreateKeyVaultAndCertificateForServiceFabric.ps1)

    a.  Currently there is a bug in which Primary and Secondary secrets should be in a different Key Vault in the same region for the deployment to succeed.

    b.  If you use the same key vault to put your secondary secret, you may get the following error in step 2)

> ![Update-Azur eRmVmss
> . List secrets contains repeated instances of /subscriptions/{redacted}/resourceGroups/{redacted}/... which is disallowed
> StatusCode: 400
> Reasonphrase: Bad Request](../media/certswap_image1.png)


2.  Add the cert to the VMSS - [Add new cert to VMSS](./Add_New_Cert_To_VMSS.ps1)


3.  *(optional)* Change Advanced Upgrade Settings to use shorter times, which speeds up the cert add and swap operations significantly

```Batch
Health check retry timeout - set to 00:02:00
Health check wait duration - set to 00:00:30
Health check stable duration - set to 00:00:30  
```

4.  Add new Cert thumbprint in Secondary Certificate slot

    From PowerShell run [Add-AzureRmServiceFabricClusterCertificate](https://docs.microsoft.com/en-us/powershell/module/azurerm.servicefabric/Add-AzureRmServiceFabricClusterCertificate?view=azurermps-4.1.0)

```PowerShell
Add-AzureRmServiceFabricClusterCertificate -ResourceGroupName 'Group1' -Name 'Contoso01SFCluster' -SecretIdentifier '<https://contoso03vault.vault.azure.net/secrets/contoso03vaultrg/7f7de9131c034172b9df37ccc549524f>'
```

5.  Swap cert in Portal
	
* Azure Portal -> ResourceGroup -> Cluster -> Security
	* Select the Secondary certificate
	* Click ellipse ( ... ) and pick **Swap with Primary**


**NOTE:** Starting with Service Fabric 5.7, only the cert with the farthest expiration date can be used for authentication unless modifying setting UseSecondaryIfNewer in manifest. Once a new cert has been added to environment regardless if secondary or primary, only the newer cert will be used (assuming the new cert expiration date is further than existing cert) **


6.  Delete old cert from Portal (now secondary)

* Azure Portal -> ResourceGroup -> Cluster -> Security
	* Select the Secondary certificate
	* Click ellipse ( ... ) and pick **Delete** 

or

From PowerShell run [Remove-AzureRmServiceFabricClusterCertificate](https://docs.microsoft.com/en-us/powershell/module/azurerm.servicefabric/Remove-AzureRmServiceFabricClusterCertificate)

```PowerShell
Remove-AzureRmServiceFabricClusterCertificate -ResourceGroupName 'Group1' -Name 'Contoso01SFCluster' -Thumbprint '5F3660C715EBBDA31DB1FFDCF508302348DE8E7A
```

7.  (optional) Change Advanced Upgrade Settings back to use original healthcheck times

```Batch
Health check retry timeout - set to 00:45:00
Health check wait duration - set to 00:05:00
Health check stable duration - set to 00:05:00
```

