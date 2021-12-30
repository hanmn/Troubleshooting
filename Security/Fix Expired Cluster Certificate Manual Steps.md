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

1. Create new cert in different KeyVault - [CreateKeyVaultAndCertificateForServiceFabric.ps1](../Scripts/CreateKeyVaultAndCertificateForServiceFabric.ps1) 

2. Deploy new cert to all nodes in VMSS - [Add_New_Cert_To_VMSS.ps1](../Scripts/Add_New_Cert_To_VMSS.ps1) 


## For each node { 

3. RDP into **each** VM and make sure the certificate is present and the private key is already ACL'd to 'Network Service'  

    * Run certlm.msc 

    * Find the new certificate 

    * Right click cert, Manage Private Keys, ensure NETWORK SERVICE has full permissions 

    * If RDP to each node is not feasible, alternatively you can automate through [Desired State Configuration](https://docs.microsoft.com/en-us/powershell/dsc/azuredsc "https://docs.microsoft.com/en-us/powershell/dsc/azuredsc")

 

4. Stop both "Azure Service Fabric Node Bootstrap Agent" and "Microsoft Service Fabric Host Service" service (run in this exact order) 

    * net stop ServiceFabricNodeBootstrapAgent 

    * net stop FabricHostSvc 

  

5. Locate ClusterManifest.current in the SvcFab folder like "D:\SvcFab\_sys_0\Fabric\ClusterManifest.current.xml" according to actual datapath deployed, and copy to somewhere like D:\Temp\clusterManifest.xml 

    * Modify the D:\Temp\clusterManifest.xml and update with new thumbprint. 

    * Replace all occurrences of old cert with the new thumbprint 

        Note: Any deployed applications using old cert for application encryption\ssl\etc will need to be redeployed with the updated thumbprint *after* the cluster is restored 

  

6. Run following cmdlet to update the Service Fabric cluster, replace the SvcFab path according to the actual path.  Verify the Node version, use latest 

    ```PowerShell
    New-ServiceFabricNodeConfiguration -FabricDataRoot "D:\SvcFab" -FabricLogRoot "D:\SvcFab\Log" -ClusterManifestPath "D:\Temp\clusterManifest.xml" -InfrastructureManifestPath "D:\SvcFab\_sys_0\Fabric\Fabric.Data\InfrastructureManifest.xml"  
    ```
 

7. Edit  "D:\SvcFab\\_sys_0\Fabric\Fabric.Package.current.xml" 

    * Note down the value for "ManifestVersion" attribute on line 2

    * Cd into the corresponding folder 

        ```batch
        cd D:\SvcFab\_sys_0\Fabric\Fabric.Config.4.131473098266979018
        ```

    * Edit "D:\SvcFab\_sys_0\Fabric\Fabric.Config.4.131473098266979018\Settings.xml" 

    * Replace all occurrences of old cert with the new thumbprint 


8. Start both services "Microsoft Service Fabric Host Service" and "Azure Service Fabric Node Bootstrap Agent" again **(run in this exact order)**

    ```PowerShell
    net start FabricHostSvc 
    net start ServiceFabricNodeBootstrapAgent 
    ```
 

9. Open Task Manager and wait for a couple minutes to verify that **FabricGateway.exe** is running 

## } 

 

10. After all the nodes have been updated (or at least all the seed nodes), services should be restarting and when ready you see FabricGateway.exe running you can try to reconnect to the cluster over SFX and PowerShell from your development computer.  *(Make sure you have installed the new Cert to `CurrentUser\My`)*

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

**Note 2**: The cluster will not display Nodes/applications/or reflect the new Thumbprint yet because the Service Fabric Resource Provider (SFRP) record for this cluster has not be updated with the new thumbprint.  To correct this Contact Azure support to **create a support ticket from the Azure Portal for this cluster** to request the final update to the SFRP record with the new thumbprint.


11. The last step will be to update the cluster ARM template to reflect the location of the new Cert / Keyvault 

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