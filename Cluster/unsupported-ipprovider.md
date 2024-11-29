# Recover an unsupported cluster that is using Open Networking after Jan 19th

This article will demonstrate how to try to recover a cluster that is on an unsupported version that is using Open Networking and it is down, in order to upgrade the cluster.

## [Applies to]

**All** Service Fabric clusters running 6.3 or higher that uses the Open Network Container feature and that are not upgraded to a version as detailed in [LINK to unsupported].

## [Symptoms]  

   * Cluster is using Open Network, not upgraded and the cluster is down
   * Cluster State 'UpgradeServiceNotReachable' in Azure Portal
   * Application/Node details are not displayed in Azure Portal
   * Unable to connect to the cluster through SFX/PowerShell
   * Node(s) goes down for any reason and cannot restart (stuck down)

## [Remediation]

* RDP into the node of question
* Find Fabric data root directory: 
C:\WFRoot on a PaaS V1 VM 
D:\SvcFab on a VMSS VM (mostly) 

* Find FabricHostSettings.xml
* Make a backup of the FabricHostSettings.xml file
* Open the FabricHostSettings.xml file
Look for the Hosting section and the parameter "IPProviderEnabled":

```xml
  <Section Name="Hosting">
  ...
    <Parameter Name="IPProviderEnabled" Value="true" />
```

Replace that with Value="false"


```xml
  <Section Name="Hosting">
  ...
    <Parameter Name="IPProviderEnabled" Value="false" />
```

The node would pick up the change and should start normally. All service fabric processes (Fabric, FabricHost, etc) should start normally.

* Need to do the above steps on every node on the cluster

When all the nodes have the settings disabled, the clusters should come back online. The applications that are using open networking won't work since the setting is disabled.
* Need to open a Support Ticket with Microsoft to disable the same IPProviderEnabled setting in the backend configuration (so upgrade will be able to proceed)
* Upgrade the cluster to a supported version

## [Additional References]

