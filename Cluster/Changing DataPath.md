# Changing DataPath

Customer sometimes change the DataPath for their cluster to avoid using temporary D: which is destroyed if the VM or VMSS is deallocated.  This can happen if the subscription spending limits are reached or if they are trying to save on resource expenses by deallocating on the weekends or between QA milestones.

This Article from Matt Schneider discusses this and why it can cause performance issues.

You can change Setup/FabricDataRoot to move the Service Fabric local installation and all of the local application working directories, and/or TransactionalReplicator/SharedLogPath to move the reliable collections shared log.

## **Some things to consider**

Service Fabric Services (and Service Fabric itself) are built to work on local disks and generally should not be hosted on XStore backed disks (premium or not):

- Reliable Collections are definitely built to operate against local drives. There's no internal testing that I'm aware of that runs them in this configuration.

- Waste of I/O: Assuming LRS replicates changes 3 times and you set TargetReplicaSetSize to 3, this configuration will generate 9 copies of the state. Do you need 9 copies of your state?

- Impact on Latency and Performance: What should be a local disk IO will turn into network + disk IO, which has a chance to hurt your performance.

- Impact on Availability: At a minimum you're adding another dependency, which usually reduces overall availability. If storage ever has an issue you're now more coupled to that other service. Today you're pretty coupled already since the VMSS drives are backed by blobs, so VM provisioning would fail, but that's different than the read/write/activation path for your services.

## **References** 

https://stackoverflow.com/questions/42379769/utilize-managed-disk-for-service-fabric-temporary-storage/42520824#42520824
