# Recover an unsupported cluster that is using Open Networking after Jan 19th

This article will demonstrate how to try to recover a cluster that is on an unsupported version that is using Open Networking and it is down, in order to upgrade the cluster.

## [Applies to]

**All** Service Fabric clusters running 6.3 or higher that uses the Open Network Container feature and that are not upgraded to a version as detailed in [LINK to unsupported].

## [Symptoms]  

   * Cluster is using Open Network, not upgraded and the cluster is down

## [Remediation]

* RDP into the node of question
* Find Fabric data root directory: 
C:\WFRoot on a PaaS V1 VM 
D:\SvcFab on a VMSS VM (mostly) 

* Find Fabric.Package.current.xml under DataRoot\NodeName\Fabric\Fabric.Package.current.xml and make a backup of the file 
* Open Fabric.Package.Current.xml and find DigestedConfigPackage.ConfigPackage version, like "<ConfigPackage Name="Fabric.Config" Version="2.7.131187916901185265" />" in the example. 

The config package folder would be  DataRoot\NodeName\Fabric\ConfigPackageName.ConfigPackageVersion, like DataRoot\NodeName\Fabric\Fabric.Config.2.7.131187916901185265 in the example. 
 
```xml
<?xml version="1.0" encoding="utf-8"?> 
<ServicePackage xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="Fabric" ManifestVersion="2.7" RolloutVersion="1.0" xmlns="http://schemas.microsoft.com/2011/01/fabric"> 
  <DigestedServiceTypes RolloutVersion="1.0"> 
    <ServiceTypes> 
      <StatefulServiceType ServiceTypeName="Fabric" /> 
      <StatefulServiceType ServiceTypeName="DCA" /> 
    </ServiceTypes> 
  </DigestedServiceTypes> 
  <DigestedCodePackage RolloutVersion="1.0"> 
    <CodePackage Name="Fabric" Version=""> 
      <EntryPoint> 
        <ExeHost> 
          <Program>Fabric.exe</Program> 
        </ExeHost> 
      </EntryPoint> 
    </CodePackage> 
  </DigestedCodePackage> 
  <DigestedCodePackage RolloutVersion="1.0"> 
    <CodePackage Name="DCA" Version=""> 
      <EntryPoint> 
        <ExeHost> 
          <Program>FabricDCA.exe</Program> 
        </ExeHost> 
      </EntryPoint> 
    </CodePackage> 
  </DigestedCodePackage> 
  <DigestedConfigPackage RolloutVersion="1.0"> 
    <ConfigPackage Name="Fabric.Config" Version="2.7.131187916901185265" /> 
  </DigestedConfigPackage> 
  <DigestedDataPackage RolloutVersion="1.0"> 
    <DataPackage Name="Fabric.Data" Version="" /> 
  </DigestedDataPackage> 
  <DigestedResources RolloutVersion="1.0" /> 
</ServicePackage> 
```

* Find settings.xml from the config package folder, like DataRoot\NodeName\Fabric\Fabric.Config.2.7.131187916901185265\Settings.xml in your example 

* Make a backup of the settings.xml
* Open the settings.xml file
Look for the Hosting section and the parameter "IPProviderEnabled":

```xml
  <Section Name="Hosting">
  ...
    <Parameter Name="IPProviderEnabled" Value="true" />
```

Replace that with Value="false"


```xml
  <Section Name="Hosting">
  ...
    <Parameter Name="IPProviderEnabled" Value="false" />
```

* Make a dummy change in Fabric.Package.current.xml (e.g. add an empty line) 

The node would pick up the change and should start normally (without the IP

* Need to do the above steps on every node on the cluster

When all the nodes have the settings disabled, the clusters should come back online. The applications that are using open networking won't work since the setting is disabled.

## [Additional References]

