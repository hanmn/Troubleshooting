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

1. Create new cert in different KeyVault using [CreateKeyVaultAndCertificateForServiceFabric.ps1](https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Security/CreateKeyVaultAndCertificateForServiceFabric.ps1)

2. Deploy new cert to all nodes in VMSS using [Add_New_Cert_To_VMSS.ps1](./blob/master/Security/Add_New_Cert_To_VMSS.ps1)

3. RDP into node 0 for each NodeType in the cluster

    * if a cluster has a single nodetype they only need to RDP into one of the nodes

    * If a cluster has multiple nodetypes they need to RDP into one node on each nodetype
 
4. For each nodetype you are mitigating, open PowerShell ISE (verify it is running as Administrator)
    * Download [FixExpiredCert.ps1](../blob/master/Security/FixExpiredCert.ps1)

    * Open PowerShell ISE and edit Parameter values as necessary ($oldThumbprint, $newThumbprint, $nodeIpArray)

        Note: $nodeIpArray should list IP addresses for all nodes in the specific vnet for the nodetype you are working on

```PowerShell
        Param(
            [Parameter(Mandatory=$false)]
            [ValidateNotNullOrEmpty()]
            [string] $clusterDataRootPath="D:\SvcFab",

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
    --->    [string]$oldThumbprint="replace with expired thumbprint",

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
    --->    [string]$newThumbprint="replace with new thumbprint",

            [Parameter(Mandatory=$false)]
            [ValidateNotNullOrEmpty()]
            [string]$certStoreLocation='Cert:\LocalMachine\My\',

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
    --->    [string[]]$nodeIpArray=@("10.0.0.4","10.0.0.5","10.0.0.6" )
        )
```

5. Run the FixExpiredCert.ps1 script on each nodetype (https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-nodetypes)

    * It should prompt for the RDP credentials and then remotely execute all the necessary mitigation steps for each node listed in the nodeIpArray using Remote PowerShell

        Note: If there are any errors or issues when running the script you can attempt to fix\correct these and just rerun the script, changes are idempotent.  In some cases if there are many nodes and you know the mitigation was already successful on some nodes before the script failed then you can remove those from the nodeIpArray to speed things up, but there is no harm if the mitigation is run multiple times on the same node.
 
6. After step 5 services should be restarting and when ready you should able to reconnect to the cluster over SFX and PowerShell from your development computer.  *(Make sure you have installed the new Cert to CurrentUser\My)*

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

        Note 1: Please give the cluster 5-10 minutes to reconfigure.  Generally speaking you will see Fabric.exe startup in the Task Manager and a few minutes later FabricGateway.exe will start when the nodes have finished reconfiguration.  At this point the cluster should be running using the new certificate and SFX endpoint and PowerShell endpoints should be accessible.

        Note 2: The cluster will not display Nodes/applications/or reflect the new Thumbprint yet because the Service Fabric Resource Provider (SFRP) record for this cluster has not be updated with the new thumbprint.  To correct this Contact Azure support to create a support ticket to request the final update to the SFRP record.
 
7. The last step will be to update the cluster ARM template to reflect the location of the new Cert / Keyvault

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