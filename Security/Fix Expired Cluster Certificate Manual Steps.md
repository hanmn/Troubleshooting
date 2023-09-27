# [UPDATE 10/05/2019] 
Service Fabric clusters running 6.5 CU3 or later (version 6.5.658.9590 or higher), secured with self-signed certificates declared by thumbprint can now follow this much simpler process.

* [Fix Expired Cluster Certificate](../Security/How%20to%20recover%20from%20an%20Expired%20Cluster%20Certificate.md)


## [Symptom] 
   * Cluster will show 'Upgrade Service not reachable' warning message 
   * Unable to see the SF Nodes in the Portal or SFX 
   * Error message related to Certificate in  '%SystemRoot%\System32\Winevt\Logs\Microsoft-ServiceFabric%4Admin.evtx'  event log from 'transport' resource  

## [Verify Certificate Expired Status on Node]
   * RDP to any node
        * Open the Certificate Mgr for 'Local Computer' and check below details  
        * Make sure certificate is ACL'd to network service  
        * Verify the Certificate Expiry, if it is expired, follow below steps  


## [Fix Expired Cert steps] 

1. Create new certificate to replace the expired certificate (choose one)

  > a. Create with any reputable CA  
  > b. Generate self-signed certs using Azure Portal -> Key Vault.  
  > c. Create and upload using PowerShell - [CreateKeyVaultAndCertificateForServiceFabric.ps1](../Scripts/CreateKeyVaultAndCertificateForServiceFabric.ps1)

2. Deploy new cert to all nodes in VMSS, go to <https://resources.azure.com>, navigate to the virtual machine scale set configured for the cluster:

```
    subscriptions
    └───%subscription name%
        └───resourceGroups
            └───%resource group name%
                └───providers
                    └───Microsoft.Compute
                        └───virtualMachineScaleSets
                            └───%virtual machine scale set name%
```

![Azure Resource Explorer](../media/resourcemgr1.png)

3. Click "Read/Write" permission and "Edit" to edit configuration.

![Read/Write](../media/resourcemgr3.png)  
![Edit](../media/resourcemgr2.png)

4. Modify **"virtualMachineProfile / osProfile / secrets"**, to add (deploy) the new certificate to each of the nodes in the nodetype. Choose one of the options below:

> a. If the new certificate is in the **same Key Vault** as the Primary, add **"certificateUrl"** and **"certificate"** store to existing array of **"vaultCertificates"** as shown below:

```json
  "virtualMachineProfile": {
    "osProfile": {
    …
      "secrets": [
        {
          "sourceVault": {
            "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sampleVaultGroup/providers/Microsoft.KeyVault/vaults/samplevault"
        },
        "vaultCertificates": [
          {
            "certificateUrl": "https://samplevault.vault.azure.net/secrets/clustercert001/d5eeaf025c7d435f81e7420393b442a9",
            "certificateStore": "My"
          },
          {
            "certificateUrl": "https://samplevault.vault.azure.net/secrets/clustercert002/77ff7688258a41f7b0afdd890eb4aa8c",
            "certificateStore": "My"
          }
        ]
      }
    ]
```

> b. If the new certificate is in a **different Key Vault** as the Primary, add an additional secret to the array of **"secrets"** with **"sourceVault"** and **"vaultCertificates"** configuration as shown below:

```json
  "virtualMachineProfile": {
    "osProfile": {
    …
    "secrets": [
      {
        "sourceVault": {
          "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sampleVaultGroup/providers/Microsoft.KeyVault/vaults/samplevault"
        },
        "vaultCertificates": [
          {
            "certificateUrl": "https://samplevault.vault.azure.net/secrets/clustercert001/d5eeaf025c7d435f81e7420393b442a9",
            "certificateStore": "My"
          }
        ]
      },
      {
        "sourceVault": {
          "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/sampleVaultGroup/providers/Microsoft.KeyVault/vaults/samplevault2"
        },
        "vaultCertificates": [
          {
            "certificateUrl": "https://samplevault2.vault.azure.net/secrets/clustercert002/77ff7688258a41f7b0afdd890eb4aa8c",
            "certificateStore": "My"
          }
        ]
      }
    ]
```

5. At top of page, click PUT.

![Click PUT](../media/resourcemgr7.png)

6. **Wait** for the virtual machine scale set Updating the secondary certificate to complete. At the top of page, click GET to check status. Verify "provisioningState" shows "Succeeded". If "provisioningState" equals "Updating", continue to periodically click GET at top of page to requery scale set.

![GET](../media/resourcemgr2.png)
![resources.azure.com vmss provisioningstate succeeded](../media/resourcemgr11.png)

## For each node { 

7. RDP into **each** VM and make sure the certificate is present and the private key is already ACL'd to 'Network Service'  

    * Run certlm.msc 

    * Find the new certificate 

    * Right click cert, Manage Private Keys, ensure NETWORK SERVICE has full permissions 

    * If RDP to each node is not feasible, alternatively you can automate through [Desired State Configuration](https://docs.microsoft.com/en-us/powershell/dsc/azuredsc "https://docs.microsoft.com/en-us/powershell/dsc/azuredsc")



8. Stop both "Azure Service Fabric Node Bootstrap Agent" and "Microsoft Service Fabric Host Service" service (run in this exact order) 

    * net stop ServiceFabricNodeBootstrapAgent

    * net stop FabricHostSvc

There is a race condition where sometimes `FabricInstallerService.exe` is stuck in a crashing loop. If this is the case first launch `Services.msc` and identify 3 Services:

- FabricInstallerService
- FabricHostService
- ServiceFabricNodeBootstrapAgent

Then, set all services to startup type `Disabled`, and reboot the machine. On reboot `FabricInstallerService.exe` should never run. Continue along with the TSG.


9. Locate ClusterManifest.current in the SvcFab folder like "D:\SvcFab\\_sys_0\Fabric\ClusterManifest.current.xml" according to actual datapath deployed, and copy to somewhere like D:\Temp\clusterManifest.xml 

    * Modify the D:\Temp\clusterManifest.xml and update with new thumbprint. 

    * Replace all occurrences of old cert with the new thumbprint 

        Note: Any deployed applications using old cert for application encryption\ssl\etc will need to be redeployed with the updated thumbprint *after* the cluster is restored 

10. Locate InfrastructureManifest.xml in the SvcFab folder like "D:\SvcFab\_sys_0\Fabric\Fabric.Data\InfrastructureManifest.xml" 

    * Replace all occurrences of old cert with the new thumbprint

11. Run following cmdlet to update the Service Fabric cluster, replace the SvcFab path according to the actual path.  Verify the Node version, use latest 

    ```PowerShell
    New-ServiceFabricNodeConfiguration -FabricDataRoot "D:\SvcFab" -FabricLogRoot "D:\SvcFab\Log" -ClusterManifestPath "D:\Temp\clusterManifest.xml" -InfrastructureManifestPath "D:\SvcFab\_sys_0\Fabric\Fabric.Data\InfrastructureManifest.xml"  
    ```
 

12. Edit  "D:\SvcFab\\_sys_0\Fabric\Fabric.Package.current.xml" 

    * Note down the value for "ManifestVersion" attribute on line 2

    * Cd into the corresponding folder 

        ```batch
        cd D:\SvcFab\_sys_0\Fabric\Fabric.Config.4.131473098266979018
        ```

    * Edit "D:\SvcFab\_sys_0\Fabric\Fabric.Config.4.131473098266979018\Settings.xml" 

    * Replace all occurrences of old cert with the new thumbprint 


13. Start both services "Microsoft Service Fabric Host Service" and "Azure Service Fabric Node Bootstrap Agent" again **(run in this exact order)**

    ```PowerShell
    net start FabricHostSvc 
    net start ServiceFabricNodeBootstrapAgent 
    ```

If you previously encountered a race condition where `FabricInstallerService.exe` was crashing you can use `Services.msc` to reset the following services to these startup types. Be sure to set:

- FabricInstallerService -> Manual
- FabricHostService -> Automatic
- ServiceFabricNodeBootstrapAgent -> Automatic



14. Open Task Manager and wait for a couple minutes to verify that **FabricGateway.exe** is running 

## } 

 

15. After all the nodes have been updated (or at least all the seed nodes), services should be restarting and when ready you see FabricGateway.exe running you can try to reconnect to the cluster over SFX and PowerShell from your development computer.  *(Make sure you have installed the new Cert to `CurrentUser\My`)*

```PowerShell
        $ClusterName= "clustername.cluster_region.cloudapp.azure.com:19000"
        $Certthumprint = "{replace_with_ClusterThumprint}"

        Connect-ServiceFabricCluster -ConnectionEndpoint $ClusterName -KeepAliveIntervalInSec 10 `
            -X509Credential `
            -ServerCertThumbprint $Certthumprint  `
            -FindType FindByThumbprint `
            -FindValue $Certthumprint `
            -StoreLocation CurrentUser `
            -StoreName My 
```

**Note 1**: Please give the cluster 5-10 minutes to reconfigure.  Generally speaking you will see Fabric.exe startup in the Task Manager and a few minutes later FabricGateway.exe will start when the nodes have finished reconfiguration.  At this point the cluster should be running using the new certificate and SFX endpoint and PowerShell endpoints should be accessible. 

**Note 2**: The cluster will not display Nodes/applications/or reflect the new Thumbprint yet because the Service Fabric Resource Provider (SFRP) record for this cluster has not been updated with the new thumbprint.  To correct this Contact Azure support to **create a support ticket from the Azure Portal for this cluster** to request the final update to the SFRP record with the new thumbprint.


16. The last step will be to update the cluster ARM template to reflect the location of the new Cert / Keyvault 

    * Go to https://resources.azure.com --> Resource Group --> providers --> Microsoft.Compute --> vmss 


Ensure the correct KeyVault for the new cert is listed, update the "sourceVault" and "certificateUrl" properties

```json
            "secrets": [
            {
                "sourceVault": {
                "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/xxxxxx/providers/Microsoft.KeyVault/vaults/xxxxxxxx"
                },
                "vaultCertificates": [
                {
                    "certificateUrl": "https://xxxxxx.vault.azure.net/secrets/xxxxxx/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
                    "certificateStore": "My"
                }
                ]
            }
```

Update the "thumbprint" propert with the new certificate thumbprint 

```json
            "extensionProfile": {
                "extensions": [
                {
                    "properties": {
                    "autoUpgradeMinorVersion": true,
                    "settings": {
                        "clusterEndpoint": "https://xxxxx.servicefabric.azure.com/runtime/clusters/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
                        "nodeTypeRef": "sys",
                        "dataPath": "D:\\\\SvcFab",
                        "durabilityLevel": "Bronze",
                        "enableParallelJobs": true,
                        "nicPrefixOverride": "10.0.0.0/24",
                        "certificate": {
                        "thumbprint": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                        "x509StoreName": "My"
                        }
```
