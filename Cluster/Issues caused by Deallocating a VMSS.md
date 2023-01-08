Issues caused by Deallocating a VMSS

## **Scenario**
To save cost, some customer want to put their service fabric to sleep when we not in use, and then only start it when we need to use it. They assume they can deallocate the scaleset to achieve this. However, the problem is once the scaleset is deallocated, restarting them dows not always work and often the deployed services are failed and need to be redeployed.

## **Recommendation**
We do not recommend deallocating a VMSS for Service Fabric Clusters, this is essentially the same as scaling to 0 nodes in the Primary nodetype and will cause cluster instability or dataloss..

see https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-scale-up-down 
- Scaling down the primary node type to less than the minimum number make the cluster unstable or bring it down. This could result in data loss for your applications and for the system services.
- The service fabric system services run in the Primary node type in your cluster. So should never shut down or scale down the number of instances in that node types less than what the reliability tier warrants. Refer to the details on [reliability tiers](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-capacity#the-reliability-characteristics-of-the-cluster) here.

Two issues with the stop (Deallocate)
- When you resize or Stop (Deallocate) a virtual machine, this action destroys the contents of the D: (temporary disk) and may even trigger placement of the virtual machine to a new hypervisor. A planned or unplanned maintenance event may also trigger this placement. This can cause dataloss on any Stateful services running on the nodes, including System services.

- It is possible on the Start (Reallocate), the VMMS can come up with a new IP address, in which case Service Fabric Resource Provider will no longer recognize the node(s) and the cluster will be down.

## **Other FAQ**
Q. Will upgrading the durability of the cluster make Dealloation safer? (https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-capacity#the-durability-characteristics-of-the-cluster)

A. **No**, Regardless of any durability level, Deallocation operation on VM Scale Set will destroy the cluster
