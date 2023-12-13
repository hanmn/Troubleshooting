# Service Fabric process list with Security Context info

| Process Name | function | Security Context |
|---|---|---|
| NodeBootstrapAgent.exe | Node bootstrap and initial configuration | System Account |
| FabricSetup.exe | Runtime installation and cluster set up process | System Account |
| FabricDeployer.exe | Configuration or upgrade deployment process | System Account |
| FabricInstallerSvc.exe | Services responsible for Fabric and cluster installation | System Account |

| Process Name | **child processes** | function | Security Context |
|---|---|---|---|
| FabricHost.exe |  | Parent Supervisor Service | System Account |
| | EventStore.Service.exe | Service Fabric EventStore Service. Responsible for managing service fabric cluster and application events viewable in SFX  | Network Service Account |
| | Fabric.exe | System Service running host. (CM, FM, etc..) | Network Service Account |
| | FabricApplicationGateway.exe | Service Fabric Reverse Proxy process and only support http or https connection | Network Service Account |
| | FabricCAS.exe | Service Fabric Container Activator Service. Responsible for management of containers with dockerd | System Account |
| | FabricDCA.exe | Fabric Diagnostics Collection Agent. Responsible for collect raw ETL, perf, dump data and send to Diagnostics store | Network Service Account |
| | FabricDnsService.exe | Service Fabric DNS Service. Responsible for mapping DNS names to service fabric service names  | Network Service Account |
| | FabricFAS.exe | Service Fabric Fault Analysis service | Network Service Account |
| | FabricGateway.exe | Gateway process. The TCP listener for 19000 and http(s) listener for 19080 by default to bridge in the management and REST functions to the service fabric cluster | Network Service Account |
| | FabricIS.exe | Service Fabric Infrastructure Service | System Account |
| | FabricRM.exe | Service Fabric Repair Manager | Network Service Account |
| | FabricUOS.exe | Service Fabric upgrade orchestration services (Standalone Cluster) | Network Service Account |
| | FabricUS.exe | Service Fabric upgrade service | Network Service Account |
| | FileStoreService.exe | File store and image store service for application package | Network Service Account |
| | ImageBuilder.exe | Application package Image builder process | Network Service Account |
| | Customer SF application | Customer stateful or stateless or guess executable process. | Network Service Account, but you can configure it through application manifest file](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-application-runas-security) |

# Service Fabric FabricHost.exe startup process tree

Below shows a typical fabrichost.exe start process tree on windows server with containers. The exact ordering of child processes starting will vary.

```text
 services.exe 
   |- FabricInstallerService.exe , "C:\Program Files\Microsoft Service Fabric\FabricInstallerService.Code\FabricInstallerService.exe"
   |- FabricHost.exe , "C:\Program Files\Microsoft Service Fabric\bin\FabricHost.exe"
   |    |- FabricSetup.exe , "C:\Program Files\Microsoft Service Fabric\bin\Fabric\Fabric.Code\FabricSetup.exe" /operation:addnodestate
   |    |    |- FabricDeployer.exe , FabricDeployer.exe
   |    |    |    |- netsh.exe , "netsh" int ipv4 set dynamicport tcp start=49152 num=16383
   |    |    |    |- netsh.exe , "netsh" int ipv4 set dynamicport udp start=49152 num=16383
   |    |    |    |- netsh.exe , "netsh" int ipv6 set dynamicport tcp start=49152 num=16383
   |    |    |    |- netsh.exe , "netsh" int ipv6 set dynamicport udp start=49152 num=16383
   |    |    |    |- dockerd.exe , "dockerd" -H localhost:2375 -H npipe:// --pidfile=D:\SvcFab\_sf_docker_pid\637190279543939871_sfdocker.pid
   |    |    |    |- logman.exe , "logman" stop FabricCounters
   |    |    |    |- logman.exe , "logman" delete FabricCounters
   |    |    |    |- logman.exe , "logman" create counter FabricCounters -cf C:\windows\TEMP\tmp16E1.tmp -f bin -si 60 -o "D:\SvcFab\Log\Perf..." -v nnnnnn -max 50 -cnf 2700
   |    |    |    |- logman.exe , "logman" start FabricCounters
   |    |- dockerd.exe , "dockerd" -H localhost:2375 -H npipe:// --debug --pidfile "D:\SvcFab\_sf_docker_pid\132279047692241242_sfdocker.pid"
   |    |- FabricCAS.exe , "C:\Program Files\Microsoft Service Fabric\bin\Fabric\Fabric.Code\FabricCAS.exe"
   |    |- FabricDCA.exe , "C:\Program Files\Microsoft Service Fabric\bin\Fabric\DCA.Code\FabricDCA.exe"
   |    |- Fabric.exe , "C:\Program Files\Microsoft Service Fabric\bin\Fabric\Fabric.Code\Fabric.exe"
   |    |- FabricApplicationGateway.exe , "C:\Program Files\Microsoft Service Fabric\bin\Fabric\Fabric.Code\FabricApplicationGateway.exe"
   |    |- FabricGateway.exe , "C:\Program Files\Microsoft Service Fabric\bin\Fabric\Fabric.Code\FabricGateway.exe" localhost:55879
   |    |- netsh.exe , C:\windows\system32\netsh.exe interface ipv4 add dnsservers name="vEthernet " address=10.0.0.4 validate=no index=1
   |    |- FabricDnsService.exe , "D:\SvcFab\_App\__FabricSystem_App4294967295\DnsService.Code.Current\FabricDnsService.exe"
   |    |- FabricUS.exe , "D:\SvcFab\_App\__FabricSystem_App4294967295\US.Code.Current\FabricUS.exe"
   |    |- FabricFAS.exe , "D:\SvcFab\_App\__FabricSystem_App4294967295\FAS.Code.Current\FabricFAS.exe"
   |    |- FabricRM.exe , "D:\SvcFab\_App\__FabricSystem_App4294967295\RM.Code.Current\FabricRM.exe"
   |    |- FileStoreService.exe , "D:\SvcFab\_App\__FabricSystem_App4294967295\FileStoreService.Code.Current\FileStoreService.exe"
   |    |- EventStore.Service.Setup.exe , "D:\SvcFab\_App\__FabricSystem_App4294967295\ES.Code.Current\EventStore.Service.Setup.exe"
   |    |- EventStore.Service.exe , "D:\SvcFab\_App\__FabricSystem_App4294967295\ES.Code.Current\EventStore.Service.exe"
   |    |- VotingData.exe , "D:\SvcFab\_App\VotingType_App8\VotingDataPkg.Code.1.0.0\VotingData.exe"
```