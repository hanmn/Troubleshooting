# 'FabricDCA' reported Warning for property 'DataCollectionAgent.DiskSpaceAvailable'

[Issue](#Issue)  
[Health State](#Health-State)  
[Description](#Description)  
[Cause](#Cause)  
[Mitigation](#Mitigation)  
[Resolution](#Resolution)  
[Reference](#Reference)  

## Issue

'FabricDCA' reported Warning for property 'DataCollectionAgent.DiskSpaceAvailable'.

## Health State

Warning

## Description

```text
'FabricDCA' reported Warning for property 'DataCollectionAgent.DiskSpaceAvailable'.
The Data Collection Agent (DCA) does not have enough disk space to operate. Diagnostics information will be left uncollected if this continues to happen.
```

## Cause

There is not enough free disk space on drive where %FabricDataRoot% (typically d:\ (temp) drive in Azure) is located.
This issue can have multiple causes:

- nodetype sku too small
- application design
- application deployment
- application data
- application versions
- application logging
- fabric logging
- fabric exceptions
- container logging
- code issues

**NOTE: Service Fabric will always have an 8GB file named replicatorshared.log in %FabricDataRoot% ("D:\SvcFab\ReplicatorLog\replicatorshared.log").**

## Mitigation

Depending on cause, there are different actions to mitigate issue.  
These steps may be necessary before resolving issue if cluster is not functioning.  
To Determine cause of issue, use [Out Of Diskspace](../Cluster/Out-of-Diskspace.md) to troubleshoot.

Depending on cause, to temporarily resolve:

- multiple application versions - delete any unneeded applications and application versions from imagestore.

- logging - delete any .etl, .trace, .blg, .log , .err, .out, or .zip files from %FabricLogRoot% (typically d:\SvcFab\Log) and subdirectories. NOTE: this may limit RCA from Microsoft Support.

- exceptions - delete any .dmp files from %FabricLogRoot% (typically d:\SvcFab\Log) and subdirectories. NOTE: this may limit RCA from Microsoft Support.

## Resolution

Ensure you are on a supported version of Service Fabric.  
Ensure nodetype is sized correctly for load and application types.  
For production workloads a minimum size of 50 GB temp drive is recommended.
See [Reference](#Reference).

Depending on cause, there are different actions to resolve issue.  
To Determine cause of issue, use [Out Of Diskspace](../Cluster/Out-of-Diskspace.md) to troubleshoot.

## Reference

https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-versions
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-capacity
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-capacity-planning

