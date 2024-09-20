# Incoming TCP Traffic Troubleshooting

1.  Verify the port mapping from the front end load balancer VIP to the back end VM DIP. This will help determine which port the client is accessing externally, and which port that maps to on the VM itself.

- Verify the configuration of the Load Balancer Rules 
```PowerShell
    $slb = Get-AzureRmLoadBalancer -Name "MyLoadBalancer" -ResourceGroupName "MyResourceGroup"
    Get-AzureRmLoadBalancerRuleConfig -LoadBalancer $slb
```

- Validate that the LB Health Probe is configured correctly for your [Application Ports](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-upgrade#application-ports)
```PowerShell
    $slb = Get-AzureRmLoadBalancer -Name "MyLoadBalancer" -ResourceGroupName "MyResourceGroup"
    Get-AzureRmLoadBalancerProbeConfig -LoadBalancer $slb
```

2.  Verify which ports Service Fabric applications are configured to listen on. Check the application's service manifest to see which port port is configured. It is also possible for a service to be configured for dynamic port binding, in which case the port number is not assigned in the service manifest file, but will be assigned at runtime from the Application Port range which is defined in the Cluster Manifest.

3.  [Check for a Network Security Group](../Security/NSG configuration for Service Fabric clusters Applied at VNET level.md) which might be blocking external traffic.

4.  RDP to the VM to determine which EXE is listening on the internal port.

- [Determine Processes Listening on Port](../Cluster/Determine%20Process%20Listening%20on%20Port.md)

5.  RDP to the VM and try to connect locally 

- ie. http://localhost:8892/api/values

6.  At this point you know how traffic should flow from the client to the server process and you can do basic network troubleshooting (ie. netmon, attach debugger, etc)

7.  For a service where the external port is load balanced to all of the backend VMs it is often not possible to determine which VM the client will be connecting to. In this scenario you have a few options to troubleshoot:

    - If long running TCP connections are used, wait for the client to connect and then try to determine which VM the client is connected to (netmon on the Azure VMs). This can be problematic if there are a large number of VMs.

    - Try to run the client from one of the VMs and connect using the DIP.

    - Add a new external port to the load balancer, mapped to only a single backend VM, and then modify the client to connect to that specific port.

