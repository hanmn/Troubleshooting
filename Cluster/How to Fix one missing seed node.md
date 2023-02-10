# NOTE: This article is depreciated for clusters running 6.4 CU3 or later.  Recent changes to the Service Fabric Resource Provider will now automatically detect and repair missing seed nodes.  Simply make sure there are an adequate number of nodes in your primary nodetype to meet the Reliability requirements, and after 15 minutes the seed node configuration should repair itself.



## How to Fix one missing seed node


## **Symptoms** 

- Cluster runtime upgrades fail
- Cluster configuration upgrades will still with a presafety check on EnsureSeedNodeQuorum.
- Application upgrades fail and give "seed quorum lost" error.
- The VM in the virtual machine scale set (Instances list) with the matching Node name listed in <Infrastructure><Votes> section was deleted and the Node is no longer showing in Service Fabric Explorer 

## **Which nodes are seed nodes?**

- run **Get-ServiceFabricClusterManifest** from PowerShell and review the <Infrastructure><Votes> configuration

```PowerShell
    PS D:\Temp> Get-ServiceFabricClusterManifest
    ...
    <Infrastructure>
        <PaaS>
        <Roles>
            <Role RoleName="sys" NodeTypeRef="sys" RoleNodeCount="5" />
        </Roles>
        <Votes>
            <Vote NodeName="_sys_0" IPAddressOrFQDN="10.0.0.4" Port="1025" />
            <Vote NodeName="_sys_1" IPAddressOrFQDN="10.0.0.5" Port="1025" />
            <Vote NodeName="_sys_2" IPAddressOrFQDN="10.0.0.6" Port="1025" />
            <Vote NodeName="_sys_3" IPAddressOrFQDN="10.0.0.7" Port="1025" />
            <Vote NodeName="_sys_4" IPAddressOrFQDN="10.0.0.8" Port="1025" />
        </Votes>
        </PaaS>
    </Infrastructure>
```

As you can see in this example, there are 5 nodes configured as seed nodes, with these specific names and ip addresses. 


## **Determine which seed node was removed**

- Review nodes in the underlying Virtual machine scale set for the primary nodetype (sys in this example)

    - View from the Azure Portal

        ![Azure Portal, Virtual machine scale set, instances](../media/oneseednode002.PNG)

    - or via PowerShell

```PowerShell
        PS C:\temp> Get-AzureRmVmssVM -ResourceGroupName "samplegroup" -VMScaleSetName "sys"

        ResourceGroupName  Name Location            Sku Capacity InstanceID ProvisioningState
        -----------------  ---- --------            --- -------- ---------- -----------------
        SAMPLEGROUP      sys_0   westus Standard_D1_v2                   0         Succeeded
        SAMPLEGROUP      sys_1   westus Standard_D1_v2                   1         Succeeded
        SAMPLEGROUP      sys_2   westus Standard_D1_v2                   2         Succeeded
        SAMPLEGROUP      sys_3   westus Standard_D1_v2                   3         Succeeded
        SAMPLEGROUP      sys_6   westus Standard_D1_v2                   4         Succeeded
```

- Comparing this list from the list of seed nodes you can see node **sys_4** appears to be missing.  The node could have been removed intentionally or by accident through a mis-configured auto-scale configuration.

## **Steps to Repair**

1.  Determine which Fault Domain (FD) and Upgrade Domain (UD) the missing seed node came from, e.g. from the cluster map in SFX. In this example node _sys_4 had been removed at some point and was replaced with _sys_6, however _sys_6 is not one of the configured seed nodes.  All our seed nodes should be evenly distributed across UD and FD boundaries, so we will conclude the missing node was from UD4 and FD4, which is where _sys_6 is currently configured.

    ![Cluster Map showing UD and FD matrix, missing node _sys_4 should have been placed in UD4/FD4](../media/oneseednode003.PNG)


2.  Increase the VMSS instance count by +1, for this example from 5 to 6 

    - This can be done 
        - From <https://resources.azure.com>
        - From Azure Portal -> Resource Group -> Scaling
        - From PowerShell - https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-manage-powershell#change-the-capacity-of-a-scale-set

    - In our example we will assume this new node is called _sys_7 

3.  RDP into the new node instance(_sys_7), we will refer to this as the **Fake seed node**. 

    - Capture the IP address, for this example we will assume the Fake seed nodes IP address is 10.0.0.11

    - Stop the Azure Bootstrap Agent and FabricHost on the VMs by running (**order matters**)

```PowerShell
        net stop ServiceFabricNodeBootstrapAgent
        net stop FabricHostSvc
```

4. Disable FabricHostSvc service in Services.msc snapin, otherwise this service can be restarted by its own.

5. Create a new temporary node configuration file on the new node in the D:\temp folder.

    - copy the file "D:\SvcFab\\_sys_7\Fabric\Fabric.Data\InfrastructureManifest.xml" to "D:\temp\InfrastructureManifest.template.xml"
    
        - Replace NodeName with the original name of the missing seednode _sys_4

        - Replace IPAddressOrFQDN with the IP Address of the **Fake seed node** (10.0.0.11)

        - Replace the FaultDomain and UpgradeDomain with values determined in step 1, "fd:4" and "4" respecively

```xml
        <?xml version="1.0" encoding="utf-8"?>
        <InfrastructureInformation xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.microsoft.com/2011/01/fabric">
            <NodeList>
                <Node NodeName="_sys_4" IPAddressOrFQDN="10.0.0.11" RoleOrTierName="sys" NodeTypeRef="sys" FaultDomain="fd:/4" UpgradeDomain="4" />
            </NodeList>
        </InfrastructureInformation>
```

6. Copy "D:\SvcFab\_sys\_7\Fabric\ClusterManifest.current.xml" to "D:\temp\newClusterManifest.xml"

7. Modify "D:\temp\newClusterManifest.xml" similar to this example to update _sys_4 to use the IP of the **Fake seed node** (without the --- lines):

```xml
<Votes>
    <Vote NodeName="_sys_0" IPAddressOrFQDN="10.0.0.4" Port="1025" \>
    <Vote NodeName="_sys_1" IPAddressOrFQDN="10.0.0.5" Port="1025" \>
    <Vote NodeName="_sys_2" IPAddressOrFQDN="10.0.0.6" Port="1025" \>
    <Vote NodeName="_sys_3" IPAddressOrFQDN="10.0.0.7" Port="1025" \>
    -------------------------------------------------------------------------------------------- ---
    <Vote NodeName="_sys_4" IPAddressOrFQDN="10.0.0.11" Port="1025" \>
    -------------------------------------------------------------------------------------------- ---
</Votes>
```

Save the file

8. Open PowerShell with local admin and run the following PS cmdlet to make the **Fake seed node** function as our original seed node _sys_4

```PowerShell
    New-ServiceFabricNodeConfiguration -ClusterManifestPath "D:\temp\newClusterManifest.xml" -InfrastructureManifestPath "D:\temp\InfrastructureManifest.template.xml"
```

9.  Delete D:\SvcFab\\_sys_7 folder

    - This step is important to allow our **Fake seed node** to assume the identity of _sys_4

10. Re-enable the stopped FabricHostSvc service

    - Do not forget to **enable** FabricHostSvc if you disabled it in step 4

```PowerShell
        net start FabricHostSvc
```

11. Watch the d:\SvcFab folder, one the FabricHostSvc starts again you should see a new folder get created with the original seed nodes name d:\SvcFab\\_sys_4.

    - If you do not see this happen, or you see the folder _sys_7 get recreated then something didn't work.  Double check your work and return to step 3 and try again.

12. Now you can restart ServiceFabricNodeBootstrapAgent

```PowerShell
        net start ServiceFabricNodeBootstrapAgent
```

13. Open task manager, and switch to the details tab.  Within a few minutes you should see **FabricGateway.exe** started up

    - Once this step is done, you will should see _sys_4 has returned and is identified in SFX as a **seed node = true** on the Node -> Essential view. 

        **Note:** if node _sys_4 is showing Disabled you should be able to Activate from SFX

14.  _sys_7 will now be shown in a down state(Error)

    - By changing the _sys_7 VMMS instance into being recognized in SF as _sys_4, we have created an inconsistency we now need to cleanup by removing the **Fake seed node**.  The Virtual machine scale set still identifies this node as _sys_7 and the Service Fabric Resource Provider thinks it is _sys_4).

        - If these cleanup steps are not done then any future VMSS reimage operations can cause the _sys_7 VMSS instance to be reset back to _sys_7 in the Service Fabric cluster and again the cluster will have a seed node missing issue.

15.  From a different machine (such as your Dev Machine) remove the **Fake seed node**

```PowerShell
    Connect-ServiceFabricCluster -ConnectionEndpoint ...
    Disable-ServiceFabricNode -NodeName _sys_7 -Intent RemoveNode    
    Disable-ServiceFabricNode -NodeName _sys_4 -Intent RemoveNode    
```

Disabling _sys_4 with the RemoveNode intent will cause a cluster upgrade which will attempt to move the **seed node** status from _sys_4 to another existing node, which in this example will be the only possible node left which is _sys_6.

    - You may see the _sys_4 node status in Disab[ling] state, you must wait until the Status is "**Disabled**"

        - Call Get-ServiceFabricClusterUpgrade to check the progress

16. Once disabled, you can reduce the VMSS instance count by 1 from the Azure Portal to remove the VM we temporarily added (_sys_7)

    - This can be done 
        - From <https://resources.azure.com>
        - From Azure Portal -> Resource Group -> Scaling
        - From PowerShell - https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-manage-powershell#change-the-capacity-of-a-scale-set

17. From the PowerShell window you can now remove the nodestate for all the nodes marked as (Down)

```PowerShell
    Connect-ServiceFabricCluster -ConnectionEndpoint ...
    Remove-ServiceFabricNodeState -NodeName _sys_7 -Force
    Remove-ServiceFabricNodeState -NodeName _sys_4 -Force
```

18. The cluster should be healthy for _sys_0,1,2,3,6 and all should be marked as 'Is Seed Node = true'

    ![_sys_4 now a seed node_](../media/oneseednode004.PNG)

## **Notes**

**Note 1** : In some cases the seed node (say _sys_1) was removed from SFX but the underlying VM Instance from the Virtual machine scale set (VMMS) was not actually deleted.  Simply rebooting this VM instance will allow the node to reconfigure and try to rejoin the cluster automatically.

**Note 2**: In some cases the seed node (say _sys_1) was removed from the VMMS but is still showing as in SFX in a **Down** state, you can follow these step.

1.  Increase the VM instance count by 1 from <https://resources.azure.com>

2.  Disable the node - **Disable-ServiceFabricNode -NodeName _sys_1 -Intent RemoveNode**  (This will trigger a complete UD walk)

3. Wait for the Cluster Upgrade to complete
    - you can verify the cluster status by calling **Get-ServiceFabricClusterUpgrade**

4.  Remove the down node by calling 'Remove-ServiceFabricNodeState -NodeName _sys_1'

