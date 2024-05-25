# Service Fabric 7.1 High CPU Fabric.exe One Node

[Issue](#Issue)  
[Symptoms](#Symptoms)  
[Cause](#Cause)  
[Impact](#Impact)  
[Mitigation](#Mitigation)  
[Resolution](#Resolution)  

## Issue

Starting in version Service Fabric 7.1, you may experience high cpu on process fabric.exe on one node in the cluster.
This applies to Service Fabric Runtime 7.1 versions prior to CU5, you can review the version number noted in [Service Fabric 7.1 CU5 Release Nodes](https://github.com/microsoft/service-fabric/blob/master/release_notes/Service-Fabric-71CU5-releasenotes.md).

If you had previously applied the original mitigation please move to the [Mitigation](#Mitigation) section.


## Symptoms

The node with high cpu will be 'primary' for 'Service fabric:/System/FailoverManagerService'.  
In Service Fabric support logs, there may be indications of this issue in following trace showing high transitions and iteration counts.  
Example trace message:

```json
"Level": Informational,
"Type": PLB.Searcher,
"Text": Search of balancing completed with 1243000 total iterations and 538471 total transitions and 0 positive transitions, no better solution found,
"NodeName": _NT_0,
"FileType": fabric,
```

## Cause

A  change in Placement and Loadbalancing calculations in earlier versions of Service Fabric release 7.1 introduced this issue.

## Impact

This issue should not have any impact to cluster environment other than high cpu for fabric.exe on one node.

## Mitigation

This issue was fixed in Service Fabric 7.1 CU5 and the mitigation settings should be removed if you have upgraded your cluster to 7.1 CU5 (or higher).

Please remove the PlacementAndLoadBalancing setting and parameters form the fabricSettings section of the Service Fabric resource and Patch deployment using powershell or resources.azure.com. Refer to [Service Fabric Cluster Config Upgrade](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-config-upgrade-azure) for modifying and deploying settings.

```json
// "fabricSettings": [
//  {
//   ...
//  },
    {
      "name": "PlacementAndLoadBalancing",
      "parameters": [
        {
          "name": "MovementPerPartitionPerRunLimit",
          "value": "0"
        },
        {
          "name": "MovementPerPartitionPerRunLimitFallbackThreshold",
          "value": "-1"
        }
      ]
    }
// ],

```

## Resolution

Upgrade the Service Fabric version of the Cluster to a version greater than or equal to 7.1 CU5 as listed here [Service Fabric 7.1 CU5 Release Nodes](https://github.com/microsoft/service-fabric/blob/master/release_notes/Service-Fabric-71CU5-releasenotes.md). 