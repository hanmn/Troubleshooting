FUS Stream Architecture - (fabric:/system/UpgradeService)

```
                                                            |------------- Service Fabric Cluster ------------|
                                                            |                                                 |
                                                            |                                                 |
[portal] <------ > [ SFRP ] <======= STREAM ====== [NSG] ===== [FabricUS.exe] ----> [Gateway] ---> [FM/CM/HM] |
                                                            |                                                 |
                                                            |                                                 |
                                                            |-------------------------------------------------|
```

## **Notes**
- Stream channel is always an outbound connection with port 443
- The NSG (if present) should allow outbound traffic to the SFRP IP Address which can be determined by calling nslookup on the BaseUrl for UpgradeService, listed in the Cluster Manifest.

```xml
        <Section Name="UpgradeService">
	      <Parameter Name="BaseUrl" Value="https://westus.servicefabric.azure.com/runtime/clusters/" /> ==> 13.91.252.58
	      <Parameter Name="CoordinatorType" Value="Paas" />
	      <Parameter Name="MinReplicaSetSize" Value="3" />
	      <Parameter Name="PlacementConstraints" Value="NodeTypeName==FEPKCWUS" />
	      <Parameter Name="TargetReplicaSetSize" Value="3" />
	      <Parameter Name="X509FindType" Value="FindByThumbprint" />
	      <Parameter Name="X509FindValue" Value="2D91F07DB23689CCFE7771F0D5847185DC43B7B7" />
	      <Parameter Name="X509StoreLocation" Value="LocalMachine" />
	      <Parameter Name="X509StoreName" Value="My" />
	    </Section>
```
- If the connection was blocked by NSG usually we'll see the evidence from Cluster Traces
- FabricUS.exe communication with SFRP will be in the SFRP Traces 

- For full details on NSG configuration for Service Fabric clusters, see [Check for a Network Security Group](../Security/NSG%20configuration%20for%20Service%20Fabric%20clusters%20(Applied%20at%20VNET%20level).md)

