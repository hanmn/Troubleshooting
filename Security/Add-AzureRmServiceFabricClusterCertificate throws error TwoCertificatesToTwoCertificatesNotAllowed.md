## Add-AzureRmServiceFabricClusterCertificate throws error **TwoCertificatesToTwoCertificatesNotAllowed**

```PowerShell
    Add-AzureRmServiceFabricClusterCertificate -ResourceGroupName xxxxxgroup -Name xxxxxx -SecretIdentifier <https://xxxxxxxx.vault.azure.net/secrets/contoso003/ebb8119c8e4e42dbb206a0c4af054803>
```

Throws error: 

```cmd
    Add-AzureRmServiceFabricClusterCertificate : Code: TwoCertificatesToTwoCertificatesNotAllowed, Message: Upgrading from 2 different certificates to 2 different certificates is not allowed.

    At line:1 char:1
    \+ Add-AzureRmServiceFabricClusterCertificate -ResourceGroupName xxxxxx \...
    \+ \~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~
    \+ CategoryInfo : NotSpecified: (:) \[Add-AzureRmServ\...sterCertificate\], Exception
    \+ FullyQualifiedErrorId : Microsoft.Azure.Commands.ServiceFabric.Commands.AddAzureRmServiceFabricClusterCertificate

    Add-AzureRmServiceFabricClusterCertificate : One or more errors occurred.
    At line:1 char:1
    \+ Add-AzureRmServiceFabricClusterCertificate -ResourceGroupName sedeast \...
    \+ \~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~\~
    \+ CategoryInfo : CloseError: (:) \[Add-AzureRmServ\...sterCertificate\], AggregateException
    \+ FullyQualifiedErrorId : Microsoft.Azure.Commands.ServiceFabric.Commands.AddAzureRmServiceFabricClusterCertificate
```

This error will thrown if the \"certificate\" property in the Service Fabric resource already has a value assigned for \"thumbprintSecondary\".

**Incorrect**

```json
    \"type\": \"Microsoft.ServiceFabric/clusters\",
    ...
    \"properties\": {
        \"clusterId\": \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\",
        \"clusterCodeVersion\": \"6.3.162.9494\",
        \"clusterState\": \"Ready\",
        \"managementEndpoint\": \"<https://xxxxxxxx.westus.cloudapp.azure.com:19080>\",
        \"clusterEndpoint\": \"<https://westus.servicefabric.azure.com/runtime/clusters/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx>\",
        \"certificate\": {
            \"thumbprint\": \"8934E0494979684F2627EE382B5AD84A8FAD6823\",
            \"thumbprintSecondary\": \"16A2561C8C691B9C683DB1CA06842E7FA85F6726\",
            \"x509StoreName\": \"My\"
        },
```


**Correct**

```json
    \"type\": \"Microsoft.ServiceFabric/clusters\",
    ...
    \"properties\": {
        \"clusterId\": \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\",
        \"clusterCodeVersion\": \"6.3.162.9494\",
        \"clusterState\": \"Ready\",
        \"managementEndpoint\": \"<https://xxxxxxxx.westus.cloudapp.azure.com:19080>\",
        \"clusterEndpoint\": \"<https://westus.servicefabric.azure.com/runtime/clusters/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx>\",
        \"certificate\": {
            \"thumbprint\": \"8934E0494979684F2627EE382B5AD84A8FAD6823\",
            \"x509StoreName\": \"My\"
        },
```
 

**Mitigation**

1. Remove the secondary certificate (thumbprintSecondary) before issuing the Add-AzureRmServiceFabricClusterCertificate cmdlet

    a. Delete old cert from Portal (now secondary)

        * Azure Portal -> ResourceGroup -> Cluster -> Security
            * Select the Secondary certificate
            * Click ellipse ( ... ) and pick **Delete** 

or

2. From PowerShell run [Remove-AzureRmServiceFabricClusterCertificate](https://docs.microsoft.com/en-us/powershell/module/azurerm.servicefabric/Remove-AzureRmServiceFabricClusterCertificate)

```PowerShell
    Remove-AzureRmServiceFabricClusterCertificate -ResourceGroupName 'Group1' -Name 'Contoso01SFCluster' -Thumbprint '16A2561C8C691B9C683DB1CA06842E7FA85F6726'
```
