## PowerShell ARM Template Deployment - How to Swap certificates using ARM deployment

>> Note: This article is only showing how to SWAP certificates already deployed to the cluster, it does not detail how to create or deploy a new secondary which requires multiple deployments.  
>>
>> **Full Steps include**
>>* Create a new certificate and add to Key Vault
>>* Deploy the new certificate to VMMS
>>* Update ServiceFabric cluster resource with new Secondary certificate
>>* Swap the certificate (this article)
>>* Delete the old certificate
>>
>>Please see [Use Azure Resource Explorer to add the Secondary Certificate](./Use%20Azure%20Resource%20Explorer%20to%20add%20the%20Secondary%20Certificate.md) for details on those steps, which could be easily adapted to ARM template deployment.

## Swap the certificate

1.  Export \"Automation Scripts\" for SF Cluster **Resource Group** from portal

    a.  Resource Group \--\> Automation Script \--\> Download

2.  Edit template.json and Swap the values of "thumbprint" and "thumbprintSecondary" properties in the VMMS resource

```json
"virtualMachineProfile": {
      "osProfile": {
        ...
        "extensionProfile": {
            "extensions": [
            {
                "properties": {
                "autoUpgradeMinorVersion": true,
                "settings": {
                    ... swap thumbprints in the two certificate properties below
                    "certificate": {
                        "thumbprint": "8934E0494979684F2627EE382B5AD84A8FAD6823",
                        "thumbprintSecondary": "16A2561C8C691B9C683DB1CA06842E7FA85F6726",
                        "x509StoreName": "My"
                    }
                },
                "publisher": "Microsoft.Azure.ServiceFabric",
                "type": "ServiceFabricNode",
                "typeHandlerVersion": "1.0"
                },
                "name": "wordcount_ServiceFabricNode"
            },
```

3.  Swap the "thumbprint" property value in "certificate" and "certificateSecondary" for the ServiceFabric Cluster resource

```json
  "type": "Microsoft.ServiceFabric/clusters",
   ...
  "properties": {
    "provisioningState": "Succeeded",
    "clusterId": "d4556f3b-e496-4a46-9f20-3db88fecdf11",
    "clusterCodeVersion": "6.3.162.9494",
    "clusterState": "Ready",
    "managementEndpoint": "https://hughsftest.westus.cloudapp.azure.com:19080",
    "clusterEndpoint": "https://westus.servicefabric.azure.com/runtime/clusters/d4556f3b-e496-4a46-9f20-3db88fecdf11",
    "certificate": {
      "thumbprint": "8934E0494979684F2627EE382B5AD84A8FAD6823",
      "x509StoreName": "My"
    },
    "certificateSecondary": {
      "thumbprint": "16A2561C8C691B9C683DB1CA06842E7FA85F6726",
      "x509StoreName": "my"
    }
```
* save the file

4.  Edit parameters.json file and delete everything in the "parameters" property which default to null when exported

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
    }
}
```

* save the file
 

5.  Run .\\deploy.ps1 and deploy the template. If everything is correct it should work and swap certificates.

