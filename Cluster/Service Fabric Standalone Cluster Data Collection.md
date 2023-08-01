# Service Fabric Standalone Cluster Data Collection

Service Fabric Standalone Cluster is a cluster that is not deployed using Azure Service Fabric Resource Provider (SFRP) as a managed service. Standalone clusters are typically deployed on-premises but can be deployed on Azure virtual machines without using SFRP as self-service.  See [standalone cluster overview](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-standalone-clusters-overview) for additional information.

Azure managed clusters provide some automated management of the cluster as well as telemetry and diagnostics to Microsoft. When opening a case with Microsoft Support, this information is already available and manual data collection is not normally required. Standalone clusters do not have these additional features so data collection if required is a manual process.  

## StandaloneLogCollector.exe download

StandaloneLogCollector.exe is a utility included in the Service Fabric Standalone runtime download that can be used to assist with data collection. Information about download content is available in [service fabric cluster standalone package contents](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-standalone-package-contents).

## StandaloneLogCollector.exe setup

1. Logon to machine with Service Fabric installed and open administrative prompt
2. Download StandaloneLogCollector.exe included in package [service fabric standalone package](https://go.microsoft.com/fwlink/?LinkId=730690)
3. Expand downloaded zip .\Microsoft.Azure.ServiceFabric.WindowsServer.#.#.#.#.zip
4. Expand embedded zip in 'Tools' extracted subdirectory .\Tools\Microsoft.Azure.ServiceFabric.WindowsServer.SupportPackage.zip
5. Copy StandaloneLogCollector.exe to a path close to root for example c:\temp. this is to prevent [Directory Path is longer than 80 characters](#Directory-Path-is-longer-than-80-characters)
6. Run StandaloneLogCollector.exe -? for command information

## StandaloneLogCollector.exe parameters

Parameter Name | Description
---------------|------------
Output|Output directory path. By default, it is generated beside the exe, and named in the format '{machine name}.{time stamp}'.
StartUtcTime|Start UTC time of trace logs to collect. By default, it is 1 hour prior to the EndUtcTime. Format: MM/dd/yyyy HH:mm:ss.
EndUtcTime|End UTC time of trace logs to collect. By default, it is now if StartUtcTime is not specified, and it is 1 hour after StartUtcTime if StartUtcTime is specified. Format: MM/dd/yyyy HH:mm:ss.
IncludeLeaseLogs|Collect lease logs. By default, lease logs are not collected.
Scope|The scope of the log collection. 'node' indicates collecting trace logs from the current node only. 'cluster' indicates collecting trace logs from all nodes. By default, it is 'cluster'.
Mode|The execution workflow of the tool. 'Collect' collects but does not upload logs. 'Upload' uploads logs collected in a previous run. 'CollectAndUpload' collects and uploads logs in the same run. By default, it is 'CollectAndUpload'.
StorageConnectionString|The Azure storage connection string provided by Microsoft support team, in the format of a SAS URL. Please add double quotes around the url string.
ClusterConfigFilePath|The json cluster configuration file path. This parameter is needed when the cluster failed during setup and has not come up.
IncludeCrashDumps|Collect crash dumps. By default, crash dumps are not collected.

## StandaloneLogCollector.exe single node collect commands

StandaloneLogCollector single node commands are used when:  

* Data from only a single node is needed
* StandaloneLogCollector -scope cluster commands are not working
* Cluster central diagnostic storage has not been configured or is not available
* Diagnostic logs are not uploading to central storage
* Cluster is not running
* Cluster is not installing

NOTE: It is recommended to use the smallest timeframe possible that represents the issue as logging is extensive.

### node collect command

```powershell
.\StandaloneLogCollector.exe -scope node -mode collect
```

### node collect command with time range

```powershell
.\StandaloneLogCollector.exe -scope node -mode collect -StartUtcTime "10/31/2019 20:00:00" -EndUtcTime "10/31/2019 22:30:00"
```

### node collect command with time range to specific output path

```powershell
.\StandaloneLogCollector.exe -scope node -mode collect -StartUtcTime "10/31/2019 20:00:00" -EndUtcTime "10/31/2019 22:30:00" -output c:\temp\collection1
```

## StandaloneLogCollector.exe cluster collect commands

StandaloneLogCollector cluster node commands are used when:  

* Data from entire cluster is needed
* general performance issues
* random issues
* when issue is not known

NOTE: It is recommended to use the smallest timeframe possible that represents the issue as logging is extensive especially when collecting from entire cluster.

### cluster collect command

```powershell
.\StandaloneLogCollector.exe -scope cluster -mode collect
```

### cluster collect command with time range

```powershell
.\StandaloneLogCollector.exe -scope cluster -mode collect -StartUtcTime "10/31/2019 20:00:00" -EndUtcTime "10/31/2019 22:30:00"
```

### cluster collect command with time range and upload to storage account

```powershell
.\StandaloneLogCollector.exe -scope cluster -mode collectAndUpload -StartUtcTime "10/31/2019 20:00:00" -EndUtcTime "10/31/2019 22:30:00" -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken"
```

## StandaloneLogCollector.exe upload commands

### cluster upload command to storage account

```powershell
.\StandaloneLogCollector.exe -mode upload -output c:\temp\collection1 -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken"
```

### Node or cluster upload command to kusto or log analytics using collectsfdata.exe

CollectSFData can be used to manage Service Fabric diagnostic data. One option is to upload data collected from standalonelogcollector.exe to kusto or log analytics. Download utility from [CollectServiceFabricData]("https://github.com/microsoft/CollectServiceFabricData/releases/latest") git repo. Use the --cacheLocation argument to specify the folder output location from standalonelogcollector.exe. For full syntax use -?.

```text
collectsfdata.exe --cacheLocation c:\temp\collection1 --kustoCluster "https://ingest-{{kusto cluster}}.{{location}}.kusto.windows.net/{{kusto database}} --kustoTable standalone_collection1

```

## Troubleshooting  

### Error when trying to use scope 'cluster'

If -scope cluster fails, try -scope node from the node(s) with issue and/or primary node with issue. There are multiple reasons for -scope cluster to fail including not having the diagnosticsstore configured or permissions set correctly. Depending on issue, logs may only be available locally on the node.

### Error when trying to use mode 'upload' or 'collectandupload'

If unable to use -mode *upload mode types, use -mode collect instead. After data has been copied into output folder, try using standalonelogcollector.exe -mode upload from another machine setting -output to the output folder. Or, if working with Microsoft support, zip output folder, and upload to case workspace.

```text
10/31/2019 2:59:40 PM,Error,MainWorkflow,Error: The remote server returned an error: (400) Bad Request.,Microsoft.WindowsAzure.Storage.StorageException: The remote server returned an error: (400) Bad Request. ---> System.Net.WebException: The remote server returned an error: (400) Bad Request.
   at System.Net.HttpWebRequest.GetResponse()
```

### Directory Path is longer than 80 characters

The trace path and filename length is long and can cause issues on machines where [LongPathsEnabled](https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file) has not been set. Use a directory with a short name to prevent this error. Example: c:\temp

```text
The default output directory path 'C:\Users\user\Downloads\Microsoft.Azure.ServiceFabric.WindowsServer.6.5.676.9590\tools\Microsoft.Azure.ServiceFabric.WindowsServer.SupportPackage\nt0000000.2019.10.26.11.48.15' is longer than 80 characters. Please specify a shorter path, like c:\myOutput
```

## Reference

```text
Usage: StandaloneLogCollector.exe -Output <output directory> -StartUtcTime <start utc time> -EndUtcTime <end utc time> -IncludeLeaseLogs -Scope <node, or cluster> -Mode <Collect, Upload, or CollectAndUpload> -StorageConnectionString <SAS URL> -ClusterConfigFilePath <Json Configuration file path> -IncludeCrashDumps

Examples:

  Example 1: StandaloneLogCollector.exe -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken"
  Example 2: StandaloneLogCollector.exe -Output c:\myOutput -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken"
  Example 3: StandaloneLogCollector.exe -StartUtcTime "01/27/2017 22:00:00" -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken"
  Example 4: StandaloneLogCollector.exe -EndUtcTime "01/27/2017 23:00:00" -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken"
  Example 5: StandaloneLogCollector.exe -Output c:\myOutput -StartUtcTime "01/27/2017 22:00:00" -EndUtcTime "01/27/2017 23:00:00" -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken"
  Example 6: StandaloneLogCollector.exe -Output c:\myOutput -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken" -ClusterConfigFilePath c:\SAPackage\ClusterConfig.json  
```

#### Example StandaloneLogCollector.exe cluster command output

```text
PS C:\temp\standalonelogcollector> .\StandaloneLogCollector.exe -scope cluster -mode collect

The privacy statement for using Microsoft Azure Service Fabric Standalone Log Collector can be found on https://privacy.microsoft.com/en-US .
Enter any key to continue.


10/31/2019 2:36:48 PM,Info,MainWorkflow,Tool version: 6.0.0.0,
10/31/2019 2:36:48 PM,Info,MainWorkflow,Parameters: OutputDirectoryPath:C:\temp\standalonelogcollector\nt0000000.2019.10.31.14.36.48;StartUtcTime:10/31/2019 1:36:48 PM;EndUtcTime:10/31/2019 2:36:48 PM;IncludeLeaseLogs:False;WorkingDirectoryPath:C:\temp\standalonelogcollector\nt0000000.2019.10.31.14.36.48.temp;Scope:Cluster;Mode:Collect;ConnectionString:;ClusterConfigFilePath:;IncludeCrashDumps:False,
10/31/2019 2:36:48 PM,Info,MainWorkflow,Workflow begins,
10/31/2019 2:36:48 PM,Info,MainWorkflow,Log collection begins,
10/31/2019 2:36:48 PM,Info,MainWorkflow,Log collection of FileLogCollector begins,
10/31/2019 2:36:49 PM,Info,MainWorkflow,Log collection of RegistryLogCollector begins,
10/31/2019 2:36:49 PM,Info,MainWorkflow,Log collection of FirewallInfoCollector begins,
10/31/2019 2:36:49 PM,Info,CollectLogs,Firewall rules: 112 out of 389 rules are collected,
10/31/2019 2:36:49 PM,Info,MainWorkflow,Log collection of DcaLogCollector begins,
10/31/2019 2:36:49 PM,Info,CollectLogs,InternalCollectLogs.CollectLogs: root path of the cluster is configured as: \\nt0000000\diagnosticsStore\fabriclogs-67612e6d-c1f8-41d3-96ae-33db7075eadf. Exists: True,
10/31/2019 2:36:49 PM,Info,CollectLogs,DcaLogCollector.CollectFabricLogs: node name filter is *,
10/31/2019 2:36:49 PM,Info,CollectLogs,InternalCollectLogs.CollectLogs: root path of the cluster is configured as: \\nt0000000\diagnosticsStore\fabricperf-67612e6d-c1f8-41d3-96ae-33db7075eadf. Exists: True,
10/31/2019 2:36:49 PM,Info,CollectLogs,DcaLogCollector.CollectPerfCounters: node name filter is *,
10/31/2019 2:36:49 PM,Info,CollectLogs,InternalCollectLogs.CollectLogs: root path of the cluster is configured as: \\nt0000000\diagnosticsStore\fabricdumps-67612e6d-c1f8-41d3-96ae-33db7075eadf. Exists: True,
10/31/2019 2:36:49 PM,Info,CollectLogs,DcaLogCollector.CollectCrashDumps: skipped,
10/31/2019 2:36:49 PM,Info,MainWorkflow,Log saving begins,
10/31/2019 2:36:49 PM,Info,MainWorkflow,Log saving of FileLogCollector begins,
74/74
10/31/2019 2:37:16 PM,Info,MainWorkflow,Log saving of RegistryLogCollector begins,
1/1
10/31/2019 2:37:16 PM,Info,MainWorkflow,Log saving of FirewallInfoCollector begins,
1/1
10/31/2019 2:37:16 PM,Info,MainWorkflow,Log saving of DcaLogCollector begins,
89/89
10/31/2019 2:37:17 PM,Info,MainWorkflow,Dumping log collection result,
10/31/2019 2:37:18 PM,Info,MainWorkflow,Removing generated logs,
10/31/2019 2:37:18 PM,Info,MainWorkflow,Removing generated logs of FileLogCollector begins,
10/31/2019 2:37:18 PM,Info,MainWorkflow,Removing generated logs of RegistryLogCollector begins,
10/31/2019 2:37:18 PM,Info,MainWorkflow,Removing generated logs of FirewallInfoCollector begins,
10/31/2019 2:37:18 PM,Info,MainWorkflow,Removing generated logs of DcaLogCollector begins,
10/31/2019 2:37:18 PM,Info,MainWorkflow,Workflow ends,

Please review the information in the log package before uploading it to Microsoft: C:\temp\standalonelogcollector\nt0000000.2019.10.31.14.36.48
Press any key to complete.
```
#### Example upload command output

```
PS C:\temp\standalonelogcollector> .\StandaloneLogCollector.exe -mode upload -output .\nt0000000.2019.10.31.14.54.32\ -StorageConnectionString "https://XXX.blob.core.windows.net/containerName?sasToken"

The privacy statement for using Microsoft Azure Service Fabric Standalone Log Collector can be found on https://privacy.microsoft.com/en-US .
Enter any key to continue.


10/31/2019 2:56:16 PM,Info,MainWorkflow,Tool version: 6.0.0.0,
10/31/2019 2:56:16 PM,Info,MainWorkflow,Parameters: OutputDirectoryPath:C:\temp\standalonelogcollector\nt0000000.2019.10.31.14.54.32\;StartUtcTime:10/31/2019 1:56:16 PM;EndUtcTime:10/31/2019 2:56:16 PM;IncludeLeaseLogs:False;WorkingDirectoryPath:C:\temp\standalonelogcollector\nt0000000.2019.10.31.14.54.32\.temp;Scope:Cluster;Mode:Upload;ConnectionString:https://XXX.blob.core.windows.net/containerName?sasToken;ClusterConfigFilePath:;IncludeCrashDumps:False,
10/31/2019 2:56:16 PM,Info,MainWorkflow,Workflow begins,

Please review the information in the log package before uploading it to Microsoft: C:\temp\standalonelogcollector\nt0000000.2019.10.31.14.54.32\
Press any key to start data upload.
...
10/31/2019 2:59:40 PM,Info,MainWorkflow,Log upload of TableLogUploader begins,
10/31/2019 2:59:40 PM,Info,TaskManager,all 1 tasks succeed,
10/31/2019 2:59:40 PM,Info,MainWorkflow,Workflow ends,
```
