# [Article Purpose]
This article will demonstrate how to enable the Service Fabric cluster security setting **AcceptExpiredPinnedClusterCertificate** to recover a cluster which has collapsed due to an Expired **self-signed** cluster certificate.

## [Applys to]
**Windows** Service Fabric clusters running 6.5 CU3 (version 6.5.644.9590 or higher), secured with **self-signed** certificates declared by thumbprint.

## [Background]
Service Fabric supports auto-rollover of cluster certificates by allowing them to be declared by Subject Common Name. When coupled with certificates issued by a trusted Certification Authority, as well as a mechanism for refreshing the certificates on the nodes, this is the recommended way to secure a Service Fabric cluster, offering security and availability benefits. 

For clusters secured with certificates declared by thumbprint, rotation requires a cluster upgrade, which may pose additional risks or simply do not complete in time prior to the expiration of the certificate.  Service Fabric now supports allowing a cluster secured with Self-signed certificates declared by thumbprint, to use its cluster certificate past the certificate expiration (**Valid To**) date. The feature allows the recovery of a cluster that collapsed due to expired certificate. 

It requires explicit opt-in, and is only applicable on clusters secured with self-signed certificates declared by thumbprint. You can use the script below to enable this setting automatically.  To **manually** enable this behavior and consent to enabling this feature, do the following:

1)	Ensure that cluster is secured with self-signed certificates decalred by thumbprint.

2)	Add the following setting to the cluster manifest, see [Update Fabric Settings using Azure Resource Manager](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-config-upgrade-azure#customize-cluster-settings-using-resource-manager-templates)

```xml
    <Section Name="Security">
        <Parameter Name="AcceptExpiredPinnedClusterCertificate" Value="true" />
    </Section>
```

3) It is recommended that the cluster certificate is renewed as soon as feasible, see Additional References below.


## [Security Statement]

```statement
The mitigation you are attempting would enable the use of an expired certificate to secure the cluster. This
mitigation is only effective in clusters secured with self-signed certificates declared by thumbprint.
Allowing expired certificates in this scenario does not constitute a security risk, because the security of
the cluster in this case is provided by the key associated with the certificate, and not by a trusted
issuer or another authority. However, Service Fabric cannot ignore the expiration of the certificate
without explicit user consent. 
```

## [Symptoms] 
   * Cluster status will show 'Upgrade Service not reachable' in Azure Portal
   * The Nodes and Application will no longer be visible in the SF Nodes in the Portal
   * Service Fabric Explorer may be unavailble
   * No longer able to connect to cluster using cmdlet such as Connect-ServiceFabricCluster
   * 403 Web Exceptions in  
   '%SystemRoot%\System32\Winevt\Logs\Application.evtx'  event log from 'ServiceFabricNodeBootrapperAgent' resource
    * Error message related to Certificate in  '%SystemRoot%\System32\Winevt\Logs\Microsoft-ServiceFabric%4Admin.evtx'  event log from 'transport' resource

## Automated Script [Expired Cert, steps to enable setting AcceptExpiredPinnedClusterCertificate and recover cluster]

1. RDP into node 0 for the primary NodeType of the cluster
    
2. Open a PowerShell prompt

```PowerShell
   C:\Users\sfadmin>powershell
   Windows PowerShell
   Copyright (C) Microsoft Corporation. All rights reserved.
```

2. Download [FixExpiredCert-AEPCC.ps1](../Scripts/FixExpiredCert-AEPCC.ps1)

```PowerShell
   (new-object net.webclient).downloadfile("https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/FixExpiredCert-AEPCC.ps1","$(get-location)\FixExpiredCert-AEPCC.ps1");
```

3. Run the FixExpiredCert-AEPCC.ps1 script 

```PowerShell
   C:\Users\sfadmin> .\FixExpiredCert-AEPCC.ps1   
```

or if dowloaded to local client machine run from rdp tsclient share

```PowerShell
   C:\Users\sfadmin> \\tsclient\c\Temp\FixExpiredCert-AEPCC.ps1   
```


* It should prompt for the RDP credentials and then remotely execute the necessary mitigation steps for the clusters Seed Nodes using Remote PowerShell

* **Note**: If there are any errors or issues when running the script you can attempt to fix\correct these and just rerun the script, changes are idempotent.  In some cases if there are many nodes and you know the mitigation was already successful on some nodes before the script failed then you can remove those from the nodeIpArray to speed things up, but there is no harm if the mitigation is run multiple times on the same node.
 

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

* **Note**: Please give the cluster 5-10 minutes to reconfigure.  Generally speaking you will see Fabric.exe startup in the Task Manager and a few minutes later FabricGateway.exe will start when the nodes have finished reconfiguration.  At this point the cluster should be running again and the PowerShell endpoints should be accessible.  If you do not see this happening, review the Application event log and the Service Fabric Admin event logs to troubleshoot the reason.  

5. Once the cluster is back up and running, as verified over PowerShell, please follow this article to perform the certificate rollover.
- [Use Azure Resource Manager to manually rollover the cluster certifiate](./Use%20Azure%20Resource%20Explorer%20to%20add%20the%20Secondary%20Certificate.md)

## [Additional References]

[Create a secure Service Fabric cluster using Common Name](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-create-cluster-using-cert-cn)

[Change cluster from certificate thumbprint to common name](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-change-cert-thumbprint-to-cn)

[Manually roll over a Service Fabric cluster certificate](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-rollover-cert-cn)


