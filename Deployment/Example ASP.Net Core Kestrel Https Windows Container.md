# Example ASP.NET Core Kestrel Https Windows Container

[Requirements](#Requirements)  
[Steps](#Steps)  
[Reference](#Reference)

## Overview  

The following provides information on how to create an ASP.NET Core Kestrel Https for a Windows container.
This assumes service fabric cluster, azure container registry, and an application certificate are already configured and available.
For this example a build machine with Windows version 2004 (20H1 / May 2020 update) and nodes with Image Sku 'datacenter-core-2004-with-containers-smalldisk' will be used.

> ### :exclamation:NOTE: If service fabric is being used to stage the application certificate in the container, the certificate has to be installed in the nodes local machine certificate store *and* has to be marked as exportable. There are currently no builtin automated methods to perform this action.  

> ### :exclamation:NOTE: It is critical to have an Azure Windows SKU that supports containers and is compatible with the .NET Core version being deployed. see [Windows Server container OS and Host OS compatibility](#https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-get-started-containers#windows-server-container-os-and-host-os-compatibility) and [Virtual Machine Images](https://docs.microsoft.com/en-us/rest/api/compute/virtualmachineimages/listskus) to get current SKU list for given location.

## Requirements

- deployed service fabric cluster supporting containers and .net core
- azure container registry
- application certificate that is not the same as the cluster / client certificate and is already imported into the nodes localmachine certificate store
- build machine with docker set to windows, visual studio, and service fabric sdk installed that is compatible with service fabric cluster node OS version
- Example base ASP.NET Core Kestrel code.

## Steps

### Verification  

1. Verify Service Fabric version and sdk versions are current
1. Verify Service Fabric cluster node OS version is compatible with ASP.NET core version being deployed.
1. Verify Build machine OS version is compatible with node OS version  

### Setup repository  

1. Create new repository folder on build machine. ex: aspNetCoreKestrelHttps
1. Copy source files from [Kestrel Sample Code](https://github.com/dotnet/AspNetCore.Docs/tree/master/aspnetcore/fundamentals/servers/kestrel/samples) into new repository folder on build machine. Both 2.x and 3. are available. For this example. .NET 3.x will be used.  
    - KestrelSample.csproj
    - Program.cs
    - Startup.cs

    ![](../media/git-aspnetcore-sample-1.png)

1. Open 'KestrelSample.csproj' in Visual Studio  
1. Save 'KestrelSample.sln' as it is needed before converting to Service Fabric container  

    ![](../media/vs-solution-save-1.png)

1. Execute the KestrelSample project to verify functionality  

    ![](../media/vs-solution-run-1.png)

1. Optionally initialize github for repository folder
    - git init
    - git add --all
    - git commit -a -m 'init'

### Convert sample ASP.NET Core Kestrel application to Service Fabric container application

1. In Visual Studio, right click the 'KestrelSample' web project, select 'Add', 'Container Orchestrator Support...'

    ![](../media/vs-web-add-orchestrator-1.png)

1. Select 'Service Fabric' in dropdown

    ![](../media/vs-solution-add-orchestrator-1.png)

1. After Service Fabric Container Orchestration has been added, the solution should look similar to the following:

    ![](../media/vs-sf-container-solution-1.png)

1. Build the KestrelSample project to verify functionality  

1. Optionally commit changes
    - git add --all
    - git commit -a -m 'sf container'

### Test Service Fabric container application conversion

With the example project converted to a service fabric container application, deploy the application to cluster

  **NOTE:** It may be necessary to configure the connection parameters and container registry information if this has not been populated previously. See [Prepare your development environment on Windows](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-get-started) and [Publish the application to the cluster](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-tutorial-deploy-app-to-party-cluster#publish-the-application-to-the-cluster) for additional information.  

1. Right click the new Service Fabric project 'KestrelSampleApplication' to publish container application to cluster.

    ![](../media/vs-solution-publish-2.png)  

    ![](../media/vs-solution-publish-1.png)  

1. In Service Fabric Explorer (SFX), verify web server started in 'CONTAINER LOGS'

    ![](../media/vs-sfx-container-log-1.png)

### Import certificate into service fabric container

Detailed information for importing a certificate into a service fabric container is located here: [Import a certificate file into a container running on Service Fabric](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-securing-containers)

**NOTE:** As mentioned above, for this process, **an exportable** certificate located in the nodes 'LocalMachine' certificate store is required.

1. Add https '\<Endpoint>' to 'ServiceManifest.xml' '\<Endpoints>' element.

```xml
<Endpoint Protocol="https" Name="KestrelSampleHttpsTypeEndpoint" Type="Input" Port="8289" />
```

1. Add '\<Portbinding>' and '\<CertificateRef>' to 'ApplicationManifest.xml' '\<ContainerHostPolices>' element.

```xml
<PortBinding ContainerPort="443" EndpointRef="KestrelSampleHttpsTypeEndpoint" />
<CertificateRef X509FindValue="[KestrelSample_Certificate_Thumbprint1]" Name="MyCert1" />
```

1. Add '\<Parameter>' to 'ApplicationManifest.xml' '\<Parameters>' element for container certificate thumbprint.

```xml
<Parameter Name="KestrelSample_Certificate_Thumbprint1" DefaultValue="" />
```

1. Add '\<Parameter>' to 'Cloud.xml' '\<Parameters>' element for container certificate thumbprint. Replace '{{container certificate thumbprint goes here}}' with the thumbprint of the certificate being imported into container.

```xml
<Parameter Name="KestrelSample_Certificate_Thumbprint1" Value="{{container certificate thumbprint goes here}}" />
```

1. Using example code from [Import a certificate file into a container running on Service Fabric](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-securing-containers), add a new function to 'Program.cs' to import the existing certificate from the nodes 'LocalMachine' certificate store to the containers 'CurrentUser' certificate store.  

**NOTE:** The environment variables being enumerated in code below **are** project name specific based off of 'Name' in 'ServiceManifest.xml'. For this project example 'Certificates_KestrelSamplePkg_Code_MyCert1_PFX' and 'Certificates_KestrelSamplePkg_Code_MyCert1_PFX' are the variable names.

```c#
using System.IO;
using System.Security.Cryptography.X509Certificates;
using System.Text;

private static string certificateFilePassword;
private static string certificateFilePath;

private static void AddCertificateToStore()
{
    certificateFilePath = Environment.GetEnvironmentVariable("Certificates_KestrelSamplePkg_Code_MyCert1_PFX");
    string passwordFilePath = Environment.GetEnvironmentVariable("Certificates_KestrelSamplePkg_Code_MyCert1_Password");
    X509Store store = new X509Store(StoreName.My, StoreLocation.CurrentUser);

    certificateFilePassword = File.ReadAllLines(passwordFilePath, Encoding.Default)[0];
    certificateFilePassword = certificateFilePassword.Replace("\0", string.Empty);
    X509Certificate2 cert = new X509Certificate2(certificateFilePath, certificateFilePassword, X509KeyStorageFlags.MachineKeySet | X509KeyStorageFlags.PersistKeySet);
    store.Open(OpenFlags.ReadWrite);
    store.Add(cert);
    store.Close();
}
```

```c#
 public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.ConfigureKestrel(serverOptions =>
                    {
                        serverOptions.Listen(IPAddress.Loopback, 8378);
                        serverOptions.Listen(IPAddress.Loopback, 8379,
                            listenOptions =>
                            {
                                listenOptions.UseHttps(certificateFilePath,
                                    certificateFilePassword);
                            });
                    })
                    .UseStartup<Startup>();
                });
```

1. Add '' to 'DockerFile' to allow container to start with 'ContainerAdministrator' credentials. Administrator credentials are needed to import cert

## Reference

Windows Server container OS and Host OS compatibility: https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-get-started-containers#windows-server-container-os-and-host-os-compatibility  

ASP.NET Core Kestrel example source code: https://docs.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel?view=aspnetcore-3.1  

Kestrel web server implementation in ASP.NET Core
Securing Service Fabric containers: 
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-securing-containers  

- Kestrel Sample Code: https://github.com/dotnet/AspNetCore.Docs/tree/master/aspnetcore/fundamentals/servers/kestrel/samples

Deploy a .NET app in a Windows container: https://github.com/dotnet/AspNetCore.Docs/tree/master/aspnetcore/fundamentals/servers/kestrel/samples  

Virtual Machine Images - List Skus: https://docs.microsoft.com/en-us/rest/api/compute/virtualmachineimages/listskus


### **powershell container commands from node verifying container web server response:**

```
PS C:\Users\cloudadmin> docker ps
CONTAINER ID        IMAGE                                              COMMAND                  CREATED             STATUS              PORTS                  NAMES
97ec731cf2eb        sfjagilbercontainer.azurecr.io/kestrelsample:dev   "dotnet KestrelSampl…"   31 minutes ago      Up 31 minutes       0.0.0.0:8288->80/tcp   sf-5-6e295bfc-6a63-478f-b483-8bfd0c88e0c6_d60092ab-f541-46a9-a527-b3edd7d75f4e

PS C:\Users\cloudadmin> docker logs 97ec731cf2eb
info: Microsoft.Hosting.Lifetime[0]
      Now listening on: http://[::]:80
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
info: Microsoft.Hosting.Lifetime[0]
      Hosting environment: Production
info: Microsoft.Hosting.Lifetime[0]
      Content root path: C:\app

PS C:\Users\cloudadmin> curl http://localhost:8288 -UseBasicParsing
StatusCode        : 200
StatusDescription : OK
Content           : <!DOCTYPE html><html lang="en"><head><title></title></head><body><p>Hosted by Kestrel</p><p>Listening on the following addresses: http://[::]:80</p><p>Request URL:
                    http://localhost:8288/<p>
RawContent        : HTTP/1.1 200 OK
                    Transfer-Encoding: chunked
                    Content-Type: text/html
                    Date: Wed, 03 Jun 2020 13:10:07 GMT
                    Server: Kestrel

                    <!DOCTYPE html><html lang="en"><head><title></title></head><body><p>Hosted...
Forms             :
Headers           : {[Transfer-Encoding, chunked], [Content-Type, text/html], [Date, Wed, 03 Jun 2020 13:10:07 GMT], [Server, Kestrel]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        :
RawContentLength  : 189
```  
