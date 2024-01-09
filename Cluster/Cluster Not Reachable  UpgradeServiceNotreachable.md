# Cluster Not Reachable / UpgradeServiceNotreachable

## Symptoms

- Cluster State \'UpgradeServiceNotReachable\' in Azure Portal
- Application/Node details are not displayed in Azure Portal
- Unable to connect to the cluster through SFX/PowerShell
- Service Fabric Explorer (SFX) warnings on WrpStreamChannel

## Possible Causes

- Cluster is down due to seed node Quorum Loss / ring collapsed - too many seed nodes failed or were brought down at the same time
- fabric:/System/UpgradeService (Upgrade service) is down
- fabric:/System/UpgradeService is unable to reach regional Service Fabric Resource Provider (SFRP)
- TLS 1.0/1.2 was disabled
- Expired Certificate

## Mitigation

### Cluster down / ring collapse

Sometimes the cluster is not recoverable and the worst case is a full rebuild of the cluster.

#### VMs in VMSS associated with SF nodes deallocated

- VMs deallocated / stopped, start the VMs
- See [Issues caused by Deallocating a VMMS](./Issues%20caused%20by%20Deallocating%20a%20VMSS.md)
- See [Common issues caused by AutoScale](./Common%20issues%20customers%20experience%20when%20using%20Auto-scale%20with%20Service%20Fabric%20clusters.md)

#### VMs in VMSS associated with SF nodes are in failed state, check status of extensions on these VMs

- Validate that the configuration of failed extensions is correct
- Service Fabric extension in error, note down the error message if any
- See [Collecting logs for failed VMs](./Collecting%20logs%20for%20failed%20VMs.md) for obtaining more details about the failure and mitigation

#### VMs healthy

- Service Fabric may be failing to start up on the VM due to various issues
- RDP to one or more VMs
- Identify the list of running processes that match Fabric*.exe (in taskmanager)
  - Are any of them restarting (changing PID)
    - Fabric.exe running and not restarting may indicate the VM is fine. Collect rest of the information listed below from the VM and repeat the process for other VMs.
    - Fabric.exe not running or restarting often, collect rest of the information listed below. It is not necessary to gather information from rest of the VMs at this point.
- Check for errors in event viewer under the following
  - Applications and Services Logs \ Microsoft Service Fabric
  - Windows Logs \ System
    - Search for Service Fabric Node Bootstrap
- Copy latest three trace files matching each prefix from the VM
  - Normally under D:\SvcFab\Log\Traces
- Open a support ticket
  - Include information collected above including any warnings / errors in EventViewer
  - Indicate that the trace files from the VM(s) are available. Support engineer will reach out to get these uploaded

### Cluster is healthy but fabric:/System/UpgradeService (Upgrade service) is down

- May be a transient error, wait for a while to see if the issue self-corrects
- Cluster config upgrade stuck while copying the cluster package. This can block Upgrade Service from connecting to SFRP for the region
  - Restart the primary replica of fabric:/System/UpgradeService
  - Restart VM hosting primary replica for the service

### fabric:/System/UpgradeService is unable to reach SFRP

- Investigate why Stream Channel is broken, see [FUS Stream Architecture](./FUS%20Stream%20Architecture.md)
- NSG may be preventing the connection, see [Check for a Network Security Group](../Security/NSG%20configuration%20for%20Service%20Fabric%20clusters%20Applied%20at%20VNET%20level.md)

### TLS disabled

- See [TLS Configuration](../Security/TLS%20Configuration.md)
