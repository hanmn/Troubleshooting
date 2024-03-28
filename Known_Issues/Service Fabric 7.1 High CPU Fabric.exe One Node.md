# Service Fabric 7.1 High CPU Fabric.exe One Node

[Issue](#Issue)  
[Symptoms](#Symptoms)  
[Cause](#Cause)  
[Impact](#Impact)  
[Mitigation](#Mitigation)  
[Resolution](#Resolution)  

## Issue

Starting in version Service Fabric 7.1, you may experience high cpu on process fabric.exe on one node in the cluster.

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

A recent change in Placement and Loadbalancing calculations has introduced this issue.

## Impact

This issue should not have any impact to cluster environment other than high cpu for fabric.exe on one node.

## Mitigation

Add the following parameters in the 'fabricSettings' section of the service fabric resource and Patch deployment using powershell or resources.azure.com. Refer to [Service Fabric Cluster Config Upgrade](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-config-upgrade-azure) for modifying and deploying settings.

**Note: these settings cannot be applied before version 7.1 service fabric**

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

This will be fixed in Service Fabric 7.1 CU 5. When the fixed version of service fabric has been installed, the mitigation settings should be removed.
