# Service Fabric process list with Security Context info

| Process Name | function | Security Context | 
|---|---|---|
| NodeBootstrapAgent.exe | Node bootstrap and initial configuration | System Account |
| FabricSetup.exe | Runtime installation and cluster set up process | System Account |
| FabricDeployer.exe | Configuration or upgrade deployment process | System Account |
| FabricInstallerSvc.exe | Services responsible for Fabric and cluster installation | System Account |

| Process Name | **child processes** | function | Security Context | 
|---|---|---|---|
| FabricHostSvc.exe |  | Parent Supervisor Process | System Account | 
| | Fabric.exe | System Service running host. (CM, FM, etc..) | Network Service Account |
| | FabricDCA.exe | Fabric Diagnostics Collection Agent. Responsible for collect raw ETL, perf, dump data and send to Diagnostics store | Network Service Account |
| | FabricGateway.exe | Gateway process. The TCP listener for 19000 and http(s) listener for 19080 by default to bridge in the management and REST functions to the service fabric cluster | Network Service Account |
| | FabricUS.exe | Service Fabric upgrade service | Network Service Account |
| | FabricFAS.exe | Service Fabric Fault Analysis service | Network Service Account |
| | FileStoreService.exe | File store and image store service for application package | Network Service Account |
| | FabricRM.exe | Service Fabric Repair Manager | Network Service Account |
| | FabricApplicationGateway.exe | Service Fabric Reverse Proxy process and only support http or https connection | Network Service Account |
| | FabricUOS.exe | Service Fabric upgrade orchestration services (Standalone Cluster) | Network Service Account |
| | ImageBuilder.exe | Application package Image builder process | Network Service Account |
| | Customer SF application | Customer stateful or stateless or guess executable process. | Network Service Account, but you can configure it through application manifest file](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-application-runas-security) |
