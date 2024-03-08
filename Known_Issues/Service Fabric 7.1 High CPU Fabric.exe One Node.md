# Service Fabric 7.1 High CPU Fabric.exe One Node

[Issue](#Issue)  
[Cause](#Cause)  
[Impact](#Impact)  
[Mitigation](#Mitigation)  
[Resolution](#Resolution)  

## Issue

Starting in version Service Fabric 7.1, you may experience high cpu on process fabric.exe on one node in the cluster. The node with high cpu will be 'primary' for 'Service fabric:/System/FailoverManagerService'.

## Cause

A recent change in Placement and Loadbalancing calculations has introduced this issue.

## Impact

This issue should not have any impact to cluster environment other than high cpu for fabric.exe on one node.

## Mitigation

Add the following parameters in the 'fabricSettings' section of the service fabric resource and Patch deployment using powershell or resources.azure.com. Refer to [Service Fabric Cluster Config Upgrade](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-config-upgrade-azure) for modifying and deploying settings.

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

This will be fixed in a future version (TBD) of Service Fabric.
