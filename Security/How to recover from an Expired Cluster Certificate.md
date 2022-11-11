# [Article Purpose]
This article will demonstrate how to enable the Service Fabric cluster security setting **AcceptExpiredPinnedClusterCertificate**  to recover from an Expired **self-signed** cluster certificate, on clusters running 6.5 CU3 or later (version 6.5.xxx or higher)

## [Security Statement]
*replace with verbiage from SF team*

    The main concern with accepting expired certificates applies to CA-issued ones: certs would be listed on
    only one CRL update following expiration, after which their record is purged. A compromised (or otherwise 
    revoked certificate) would have its revocation status lost as soon as it is purged from its corresponding 
    CRL after expiration, and so accepting it indefinitely opens the risk of trusting a compromised cert. 
    
    Self-signed certs, being just key containers, do not present this risk. Therefore AzSec is ok with 
    accepting expired self-signed certificates declared by thumbprint for client authentication. 
    
    This article only applys to cluster configured with x509 **self signed certs**, using thumbprints, and 
    will have no effect for clusters using clusters configured us CA Signed certs (x509 auth) or for cluster 
    configured to use Common Name using CA signed certificates.

*replace with verbiage from SF team*

## [Symptoms] 
   * Cluster will show 'Upgrade Service not reachable' warning message
   * Unable to see the SF Nodes in the Portal or SFX
   * 403 Web Exceptions in  
   '%SystemRoot%\System32\Winevt\Logs\Application.evtx'  event log from 'ServiceFabricNodeBootrapperAgent' resource
    * Error message related to Certificate in  '%SystemRoot%\System32\Winevt\Logs\Microsoft-ServiceFabric%4Admin.evtx'  event log from 'transport' resource

## [Verify Certificate Expired Status on Node]
   * RDP to any node
        * Open the Certificate Mgr for 'Local Computer' and check below details
        * Make sure certificate is ACL'd to network service
        * Verify the Certificate Expiry [Not After], if it is expired, follow below steps

## [Fix Expired Cert steps]

1. RDP into node 0 for the primary NodeType of the cluster
    
 
2. Open PowerShell ISE (verify it is running as Administrator)
    * Download [FixExpiredCert-AEPCC.ps1](../Scripts/FixExpiredCert-AEPCC.ps1)

3. Run the FixExpiredCert-AEPCC.ps1 script 

    * It should prompt for the RDP credentials and then remotely execute the necessary mitigation steps for the clusters Seed Nodes using Remote PowerShell

        Note: If there are any errors or issues when running the script you can attempt to fix\correct these and just rerun the script, changes are idempotent.  In some cases if there are many nodes and you know the mitigation was already successful on some nodes before the script failed then you can remove those from the nodeIpArray to speed things up, but there is no harm if the mitigation is run multiple times on the same node.
 
4. After executing the script the Service Fabric services should be restarting.  Once  ready (e.g. FabricGateway.exe is running) you should able to reconnect to the cluster over SFX and PowerShell from your development computer.

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

**Note 1**: Please give the cluster 5-10 minutes to reconfigure.  Generally speaking you will see Fabric.exe startup in the Task Manager and a few minutes later FabricGateway.exe will start when the nodes have finished reconfiguration.  At this point the cluster should be running again and the SFX endpoint and PowerShell endpoints should be accessible.  If you do not see this happening, review the Application event log and the Service Fabric Admin event logs to troubleshoot the reason.

