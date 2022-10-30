# 6.4 Upgrade fails for 6.3 Clusters with fabric:/System/BackupRestoreService enabled

An issue has been identified which is known to cause the Fabric 6.4 runtime upgrade to fail for clusters with the fabric:/System/BackupRestoreService enabled.

## Symptoms
During the upgrade you may see some warning/error messages in Service Fabric explorer similar to the following:

- Assert or Coding error with message 00000000-0000-0000-0000-000000007000@131873117199500233@fabric:/StateManager: Below type used in Reliable Collection urn:RetentionStore/dataStore could not be loaded. This commonly indicates that the user application is not backwards/forwards compatible. Common compatibility bugs that lead to this error are adding a new type or changing an assembly name without two phase upgrade, or removing a type. If this was caused by user's backwards/forwards compatibility bug, one way to mitigate the issue is to force the upgrade through without safety checks.

## Mitigation

- Move the fabric:/System/BackupRestoreService primary replica to the node from last Upgrade Domain and then trigger cluster upgrade.

### Steps: 
1.	Identify the node from the highest upgrade domain where BackupRestoreService's replica can be placed as per constraints, if any, and move BackupRestoreService's primary replica to this node. Assuming the identified node name as node_4, execute following PowerShell command to move the primary.
```PowerShell
Move-ServiceFabricPrimaryReplica -ServiceName fabric:/System/BackupRestoreService -PartitionId 00000000-0000-0000-0000-000000007000 -NodeName node_4
```

2.	Increase cost of replica movement for BackupRestoreService, to reduce chances of primary replica movement. Execute following PowerShell command to do this.
```PowerShell
Update-ServiceFabricService -Stateful -ServiceName fabric:/System/BackupRestoreService -DefaultMoveCost High
```

3.	Initiate upgrade of your Service Fabric Cluster to version 6.4.621.9590 or later.
 
4.	Restore replica movement cost for BackupRestoreService.
```PowerShell
Update-ServiceFabricService -Stateful -ServiceName fabric:/System/BackupRestoreService -DefaultMoveCost Low
```



## Reference
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-quickstart-azurecluster
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-backuprestoreservice-quickstart-standalonecluster
