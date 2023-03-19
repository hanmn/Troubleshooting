# Cluster Not Reachable / UpgradeServiceNotreachable

## **Symptoms**
- Cluster State \'UpgradeServiceNotReachable\'
- Application/Node details are not displayed on Portal
- Unable to connect to the cluster through SFX/PowerShell
- Service Fabric Explorer (SFX) warnings on WrpStreamChannel

## **Possible Causes**
- Cluster is down due to seed node Quorum Loss / ring collapsed - too many seed nodes have failed or were brought down at the same time
- fabric:/System/UpgradeService (Upgrade service) is down
- fabric:/System/UpgradeService is unable to reach to the regional Service Fabric Resource Provider (SFRP)
- TLS 1.0/1.2 was disabled

## **Mitigation Options**

- Cluster down / ring collapse
    - Open support ticket with Microsoft to see if the cluster is recoverable, worst case is a full rebuild of the cluster.
    - See [Issues caused by Deallocating a VMMS](./Issues%20caused%20by%20Deallocating%20a%20VMSS.md)
    - See [Common issues caused by AutoScale](./Common%20issues%20customers%20experience%20when%20using%20Auto-scale%20with%20Service%20Fabric%20clusters.md)

- fabric:/System/UpgradeService (Upgrade service) is down
    - May be a transient error, so you can wait and see if it self-corrects
    - issue with a cluster config upgrade getting stuck while copying the cluster package. This can block all polling by the Upgrade Service.
        - The workaround is to restart the primary replica of fabric:/System/UpgradeService or you can try to restart the node hosting the primary replica of fabric:/System/UpgradeService
    - See [Issues caused by Deallocating a VMMS](./Issues%20caused%20by%20Deallocating%20a%20VMSS.md)
    - See [Common issues caused by AutoScale](./Common%20issues%20customers%20experience%20when%20using%20Auto-scale%20with%20Service%20Fabric%20clusters.md)

- fabric:/System/UpgradeService is unable to reach SFRP
    - Investigate why Stream Channel is broken, see [FUS Stream Architecture](./FUS%20Stream%20Architecture.md)
    - NSG may be preventing the connection, see [Check for a Network Security Group](../Security/NSG%20configuration%20for%20Service%20Fabric%20clusters%20Applied%20at%20VNET%20level.md)

- TLS disabled
    - see [TLS Configuration](../Security/TLS%20Configuration.md)


