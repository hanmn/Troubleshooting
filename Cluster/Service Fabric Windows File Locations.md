# Service Fabric Windows File Locations

[Service Fabric Core File Locations](#Service-Fabric-Core-File-Locations)  
[Service Fabric Core File Locations Development Cluster](#Service-Fabric-Core-File-Locations-Development-Cluster)  
[Service Fabric Event Logs](#Service-Fabric-Event-Logs)  
[Guest Agent Logs (Azure deployments only)](#Guest-Agent-Logs-Azure-deployments-only)  
[Service Fabric Extension Plugin (Azure deployments only)](#Service-Fabric-Extension-Plugin-Azure-deployments-only)  
[Docker Daemon Logs](#Docker-Daemon-Logs)  

**The tables below list file locations for Service Fabric on Windows.**

## Service Fabric Core File Locations

File Path | Content
----------|----------
C:\Program Files\Microsoft Service Fabric\bin\Fabric\Fabric.Code | default service fabric core code installation path
D:\SvcFab | default application code, data, and log location
D:\SvcFab\clusterManifest.xml | service fabric cluster manifest file
D:\SvcFab\\_App | default application code and data location
D:\SvcFab\Log | default service fabric diagnostic log path
D:\SvcFab\Log\\_sf_docker_logs | service fabric docker container logs
D:\SvcFab\Log\CrashDumps | service fabric (fabric*.exe) crash dump location
D:\SvcFab\Log\Traces | service fabric .etl ([ETW](https://docs.microsoft.com/en-us/windows/win32/etw/about-event-tracing)) diagnostic trace temporary storage unformatted
D:\SvcFab\Log\work\WFab\0\Log | service fabric .dtr zip (csv) diagnostic trace temporary storage formatted files
D:\SvcFab\\< _node_name_# > | service fabric node configuration data path
D:\SvcFab\ReplicatorLog\replicatorshared.log | [sparse](https://docs.microsoft.com/en-us/windows/win32/fileio/sparse-files) (does not use size displayed) 8GB file that is required for cluster operations

## Service Fabric Core File Locations Development Cluster

File Path | Content
----------|----------
C:\SFDevCluster\Microsoft Service Fabric\bin\Fabric\Fabric.Code | default service fabric core code installation path
C:\SFDevCluster | default application code, data, and log location
C:\SFDevCluster\Data\clusterManifest.xml | service fabric cluster manifest file
C:\SFDevCluster\Data\\_App | default application code and data location
C:\SFDevCluster\Log | default service fabric diagnostic log path
C:\SFDevCluster\Log\\_sf_docker_logs | service fabric docker container logs
C:\SFDevCluster\Log\CrashDumps | service fabric (fabric*.exe) crash dump location
C:\SFDevCluster\Log\Traces | service fabric .etl ([ETW](https://docs.microsoft.com/en-us/windows/win32/etw/about-event-tracing)) diagnostic trace temporary storage unformatted
C:\SFDevCluster\Log\work\WFab\0\Log | service fabric .dtr zip (csv) diagnostic trace temporary storage formatted files
C:\SFDevCluster\Data\\< _node_name_# > | service fabric node configuration data path
C:\SFDevCluster\Data\ReplicatorLog\replicatorshared.log | [sparse](https://docs.microsoft.com/en-us/windows/win32/fileio/sparse-files) (does not use size displayed) 8GB file that is required for cluster operations

## Service Fabric Event Logs

The following logs are also viewable in 'Event Viewer' (eventvwr.exe) if 'View' -> 'Show Analytic and Debug Logs' option is enabled.

File Path | Content
----------|----------
C:\Windows\System32\winevt\logs\System.evtx | windows system event log
C:\Windows\System32\winevt\logs\Application.evtx | windows application event log
C:\Windows\System32\winevt\logs\Microsoft-ServiceFabric%4Admin.evtx | service fabric admin event log
C:\Windows\System32\winevt\logs\Microsoft-ServiceFabric%4Operational.evtx | service fabric operational event log

## Guest Agent Logs (Azure deployments only)

File Path | Content
----------|----------
C:\WindowsAzure\Logs | azure diagnostic logs
C:\WindowsAzure\Logs\AggregateStatus\aggregatestatus.json | current azure node aggregated status
C:\WindowsAzure\Logs\Plugins\ Microsoft.Azure.ServiceFabric.ServiceFabricNode\1.1.0.3\CommandExecution.log | service fabric extension startup log
C:\WindowsAzure\Logs\Plugins\ Microsoft.Azure.ServiceFabric.ServiceFabricNode\1.1.0.3\TempClusterManifest.xml | node copy of cluster manifest for last start
C:\WindowsAzure\Logs\WaAppAgent.log | windows azure application agent log

## Service Fabric Extension Plugin (Azure deployments only)

File Path | Content
----------|----------
C:\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode | service fabric extension download, configuration, and status
C:\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\ 1.1.0.3\RuntimeSettings\0.settings | service fabric extension configuration
C:\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\ 1.1.0.3\Status\0.status | service fabric extension installation status
C:\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\ 1.1.0.3\Status\HeartBeat.Json | service fabric node status
C:\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\ 1.1.0.3\InstallUtil.InstallLog | service fabric extension installation log

## Docker Daemon Logs

File Path | Content
----------|----------
C:\ProgramData\Docker | docker daemon logs