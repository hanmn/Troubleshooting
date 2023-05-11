# Collecting Service Fabric Windows node diagnostics data

When working with Microsoft support on a Service Fabric Windows cluster issue, it may be necessary to capture additional diagnostics information from one or more nodes in the cluster. 

## Default diagnostic information script will collect:
**NOTE: All of these options disabled using switch arguments when running script.**
- Windows Event Logs - System, Application, Firewall, Http, Service Fabric
- Operating System information
    - Drive configuration
    - Directory list of 'MachineKeys' folder
    - Docker information
    - Process exceptions / dumps list
    - Installed Applications
    - Installed Windows Features
    - .Net Registry export
    - Policies Registry export
    - Schannel Registry export
    - Processes
    - Services
    - Drivers
    - Hotfixes
- Network information
    - Network port tests
    - External connection test
    - DNS name resolution
    - NSLookup
    - HTTPERR log
    - Firewall Rules
    - Firewall Configuration
    - Network connections
    - Netsh SSL information
    - IP Configuration
    - WinRM settings
- Service Fabric information
    - Service Fabric registry exort
    - Directory list of fabric data root
    - Directory list of fabric root
    - Copy of Service Fabric configuration (.xml) files
    - List of Seed nodes
    - SFRP network connectivity check with installed certificate
    - REST queries to local FabricGateway for Cluster / Node / App / and Service events

## Optional diagnostic information script can collect:
- Certificate information store list
- Performance Monitor counter collection for basic performance
- Network trace

# Requirements
- Windows 2012 / Windows  2016 Service Fabric cluster
- Script files:
    - [sf-collect-node-info.ps1](../Scripts/sf-collect-node-info.ps1)
    - [event-log-manager.ps1](http://aka.ms/event-log-manager.ps1)  
        NOTE: event-log-manager.ps1 is used to process Windows Event logs and will be downloaded automatically if there is network connectivity.

# Setup
There are multiple ways to run this script to collect information.
1. RDP and run script locally on each node(s).
2. Assuming proper connectivity and authentication, from administrator machine, run script remotely for each node(s).
3. Assuming proper connectivity and authentication, RDP into a node and run script remotely for each node(s).

# Instructions
1. Copy the script files specified above to location where script will be executed. If network connectivity exists on machine where script will be executed, the following command can be used to download:
```powershell
    (new-object net.webclient).downloadfile("https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/S
    cripts/sf-collect-node-info.ps1","$pwd\sf-collect-node-info.ps1");
```
2. Preferably, open Administrator Powershell prompt.  
    **NOTE: A non-Administrator powershell prompt can be used if needed but not all data will be collected.**
3. To execute with default configuration:
```powershell
    .\sf-collect-node-info.ps1
```
4. After script has executed, instructions will be displayed showing location of zip file containing all of the diagnostics.
5. Upload diagnostics zip file to case workspace.
6. For additional information about different arguments and switches, see 'Help' information below or from command prompt type:
```powershell
    help .\sf-collect-node-info.ps1 -full
```

# Help
```
SYNOPSIS
    powershell script to collect service fabric node diagnostic data

    To download and execute with arguments:
    (new-object net.webclient).downloadfile("http://aka.ms/event-log-manager.ps1","$pwd\event-log-manager.ps1");
    (new-object net.webclient).downloadfile("https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/sf-collect-node-info.ps1","$pwd\sf-collect-node-info.ps1");
    .\sf-collect-node-info.ps1 -certInfo -remoteMachines 10.0.0.4,10.0.0.5,10.0.0.6,10.0.0.7,10.0.0.8

    upload to workspace sfgather* dir or zip


SYNTAX
    G:\github\Service-Fabric-Troubleshooting-Guides\Scripts\sf-collect-node-info.ps1 [[-workdir] <String>] [-certInfo] [[-eventLogNames] <String>] [[-externalUrl] <String>] [[-startTime] <DateTime>] [[-endTime] <DateTime>]
    [-modifyFirewall] [[-netmonMin] <Int32>] [[-networkTestAddress] <String>] [[-perfmonMin] <Int32>] [[-timeoutMinutes] <Int32>] [[-apiversion] <String>] [[-ports] <Int32[]>] [[-remoteMachines] <String[]>] [-noAdmin]
    [-noEventLogs] [-noOs] [-noNet] [-noSF] [-quiet] [[-runCommand] <String>] [<CommonParameters>]


DESCRIPTION
    To enable script execution, you may need to Set-ExecutionPolicy Bypass -Force
    script will collect event logs, hotfixes, services, processes, drive, firewall, and other OS information

    Requirements:
        - administrator powershell prompt
        - administrative access to machine
        - remote network ports:
            - smb 445
            - rpc endpoint mapper 135
            - rpc ephemeral ports
            - to test access from source machine to remote machine: dir \\%remote machine%\admin$
        - winrm
            - depending on configuration / security, it may be necessary to modify trustedhosts on
            source machine for management of remote machines
            - to query: winrm get winrm/config
            - to enable sending credentials to remote machines: winrm set winrm/config/client '@{TrustedHosts="*"}'
            - to disable sending credentials to remote machines: winrm set winrm/config/client '@{TrustedHosts=""}'
        - firewall
            - if firewall is preventing connectivity the following can be run to disable
            - Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

    Copyright 2018 Microsoft Corporation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.


PARAMETERS
    -workdir <String>
        output directory where all files will be created.
        default is $env:temp

        Required?                    false
        Position?                    1
        Default value
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -certInfo [<SwitchParameter>]
        switch to enable collection of certificate store export to troubleshoot certificate issues.
        thumbprints and serial numbers during export will be partially masked.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -eventLogNames <String>
        regex list of eventlog names to export into csv formatl
        default list should be sufficient for most scenarios.

        Required?                    false
        Position?                    2
        Default value                System$|Application$|wininet|dns|Fabric|http|Firewall|Azure
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -externalUrl <String>
        url to use for network connectivity tests.

        Required?                    false
        Position?                    3
        Default value                bing.com
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -startTime <DateTime>
        start time in normal dateTime formatting.
        example "8/26/2018 22:00"
        default -7 days.

        Required?                    false
        Position?                    4
        Default value                (get-date).AddDays(-7)
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -endTime <DateTime>
        end time in normal dateTime formatting.
        example "8/26/2018 22:00"
        default today.

        Required?                    false
        Position?                    5
        Default value                (get-date)
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -modifyFirewall [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -netmonMin <Int32>
        minutes to run network trace at end of collection after all jobs run.

        Required?                    false
        Position?                    6
        Default value                0
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -networkTestAddress <String>
        remote machine for service fabric tcp port test.

        Required?                    false
        Position?                    7
        Default value                $env:computername
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -perfmonMin <Int32>
        minutes to run basic perfmon at end of collection after all jobs run.
        cpu, memory, disk, network.

        Required?                    false
        Position?                    8
        Default value                0
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -timeoutMinutes <Int32>
        script timeout in minutes.
        script will cancel any running jobs and collect what is available if timeout is hit.

        Required?                    false
        Position?                    9
        Default value                [Math]::Max($perfmonMin,$netmonMin) + 15
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -apiversion <String>
        api version for testing fabricgateway endpoint with service fabric rest api calls.

        Required?                    false
        Position?                    10
        Default value                6.2-preview
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -ports <Int32[]>
        comma separated list of tcp ports to test.
        default ports include basic connectivity, rdp, and service fabric.

        Required?                    false
        Position?                    11
        Default value                @(1025, 1026, 19000, 19080, 135, 445, 3389, 5985)
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -remoteMachines <String[]>
        comma separated list of machine names and / or ip addresses to run diagnostic script on remotely.
        this will only work if proper connectivity, authentication, and OS health exists.
        if there are errors connecting, run script instead individually on each node.
        to resolve remote connectivity issues, verify tcp port connectivity for ports, review, winrm, firewall, and nsg configurations.

        Required?                    false
        Position?                    12
        Default value
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -noAdmin [<SwitchParameter>]
        switch to bypass admin powershell session check.
        most jobs will work with non-admin session but not all for example some of the network tests.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -noEventLogs [<SwitchParameter>]
        switch to prevent download of event-log-manager.ps1 script and collection of windows event log events.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -noOs [<SwitchParameter>]
        bypass OS information collection.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -noNet [<SwitchParameter>]
        bypass network tests.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -noSF [<SwitchParameter>]
        bypass service fabric information collection.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -quiet [<SwitchParameter>]
        disable display of folder / zip in shell at end of script.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -runCommand <String>
        command to run at end of collection.
        command needs to runnable from 'invoke-expression'

        Required?                    false
        Position?                    13
        Default value
        Accept pipeline input?       false
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS

OUTPUTS

NOTES


        File Name  : sf-collect-node-info.ps1
        Author     : microsoft service fabric support
        Version    : 180904 original
        History    :

    -------------------------- EXAMPLE 1 --------------------------

    PS C:\>.\sf-collect-node-info.ps1

    default command to collect event logs, process, service, os information for last 7 days.




    -------------------------- EXAMPLE 2 --------------------------

    PS C:\>.\sf-collect-node-info.ps1 -certInfo

    example command to query all diagnostic information, event logs, and certificate store information.




    -------------------------- EXAMPLE 3 --------------------------

    PS C:\>.\sf-collect-node-info.ps1 -startTime 8/16/2018

    example command to query all diagnostic information using start date of 08/16/2018.
    dates are used for event log and rest queries




    -------------------------- EXAMPLE 4 --------------------------

    PS C:\>.\sf-collect-node-info.ps1 -remoteMachines 10.0.0.4,10.0.0.5

    example command to query diagnostic information remotely from two machines.
    files will be copied back to machine where script is being executed.




    -------------------------- EXAMPLE 5 --------------------------

    PS C:\>.\sf-collect-node-info.ps1 -runCommand "dir c:\windows -recurse"

    example to run custom command on machine after data collection
    output will be captured in runCommand.txt





RELATED LINKS
    https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/Scripts/sf-collect-node-info.ps1
```
# Example output directory file structure:
```
PS C:\temp> tree /a /f C:\Users\CLOUDA~1\AppData\Local\Temp\2\sfColInfo-NT0000000
Folder PATH listing
Volume serial number is 000000A6 20A7:59B7
C:\USERS\CLOUDA~1\APPDATA\LOCAL\TEMP\2\SFCOLINFO-NT0000000
|   connected-nodes.txt
|   dir-fabricdataroot.txt
|   dir-fabricroot.txt
|   dir-machinekeys.txt
|   docker-info.txt
|   dotnet.reg.txt
|   drivers.txt
|   drives.txt
|   dumplist-c.txt
|   dumplist-d.txt
|   firewall-config.txt
|   firewallrules.reg.txt
|   hotfixes.txt
|   installed-apps.reg.txt
|   ipconfig.txt
|   logman-ets.txt
|   logman.txt
|   netshssl.txt
|   netstat.txt
|   netTcpConnection.txt
|   network-external-test.txt
|   nslookup.txt
|   os-info.txt
|   policies.reg.txt
|   process-summary.txt
|   processes-fabric.txt
|   processes.txt
|   resolve-dnsname.txt
|   rest-eventsApplications.txt
|   rest-eventsCluster.txt
|   rest-eventsNodes.txt
|   rest-eventsPartition.txt
|   rest-eventsServices.txt
|   rest-getClusterHealth.txt
|   rest-imageStore.txt
|   rest-nodes.txt
|   schannel.reg.txt
|   service-summary.txt
|   serviceFabric.reg.txt
|   serviceFabricNodeBootStrapAgent.reg.txt
|   services.txt
|   sfrp-response.txt
|   windows-features.txt
|   windowsupdate.log.txt
|   winrm-config.txt
|   
+---event-logs
|       event-log-manager-output.txt
|       events-all.csv
|       NT0000000-Application.csv
|       NT0000000-Microsoft-ServiceFabric-Admin.csv
|       NT0000000-Microsoft-ServiceFabric-Operational.csv
|       NT0000000-Microsoft-Windows-Windows-Firewall-With-Advanced-Security-Firewall.csv
|       NT0000000-Microsoft-WindowsAzure-Diagnostics-GuestAgent.csv
|       NT0000000-Microsoft-WindowsAzure-Diagnostics-Heartbeat.csv
|       NT0000000-Microsoft-WindowsAzure-Status-GuestAgent.csv
|       NT0000000-Microsoft-WindowsAzure-Status-Plugins.csv
|       NT0000000-System.csv
|       
+---packages
|   \---Plugins
|       +---Microsoft.Azure.Diagnostics.IaaSDiagnostics
|       |   \---1.11.3.12
|       |       |   config.txt
|       |       |   DiagnosticsPlugin.exe.config
|       |       |   DiagnosticsPluginLauncher.exe.config
|       |       |   HandlerEnvironment.json
|       |       |   HandlerManifest.json
|       |       |   manifest.xml
|       |       |   
|       |       +---ApplicationInsightsProfiler
|       |       |       ApplicationInsightsProfiler.exe.config
|       |       |       
|       |       +---Monitor
|       |       |   \---x64
|       |       |       |   MonAgent-Pkg-Manifest.xml
|       |       |       |   
|       |       |       +---Extensions
|       |       |       |   +---ApplicationInsightsExtension
|       |       |       |   |   |   ApplicationInsightsExtension.exe.config
|       |       |       |   |   |   Microsoft.AI.ServerTelemetryChannel.xml
|       |       |       |   |   |   Microsoft.ApplicationInsights.xml
|       |       |       |   |   |   Microsoft.Diagnostics.Tracing.EventSource.xml
|       |       |       |   |   |   Microsoft.Threading.Tasks.Extensions.Desktop.xml
|       |       |       |   |   |   Microsoft.Threading.Tasks.Extensions.xml
|       |       |       |   |   |   Microsoft.Threading.Tasks.xml
|       |       |       |   |   |   Newtonsoft.Json.xml
|       |       |       |   |   |   System.IO.xml
|       |       |       |   |   |   System.Runtime.xml
|       |       |       |   |   |   System.Threading.Tasks.xml
|       |       |       |   |   |   
|       |       |       |   |   \---Resources
|       |       |       |   \---MetricsExtension
|       |       |       |           MonAgent-Pkg-Manifest.xml
|       |       |       |           
|       |       |       +---procdump
|       |       |       |   +---x64
|       |       |       |   \---x86
|       |       |       \---schema
|       |       |           +---1.0
|       |       |           \---2.0
|       |       +---RuntimeSettings
|       |       |       1.settings
|       |       |       
|       |       +---schema
|       |       |       wad11JsonSchema.json
|       |       |       
|       |       +---Status
|       |       |       HeartBeat.Json
|       |       |       
|       |       \---StatusMonitor
|       \---Microsoft.Azure.ServiceFabric.ServiceFabricNode
|           \---1.1.0.2
|               |   config.txt
|               |   HandlerEnvironment.json
|               |   HandlerManifest.json
|               |   ServiceFabricExtensionHandler.exe.config
|               |   ThirdPartyNotices.txt
|               |   
|               +---ProductPackage
|               +---RuntimeSettings
|               |       1.settings
|               |       
|               +---Service
|               |   |   Checksum.txt
|               |   |   current.config
|               |   |   InfrastructureManifest.template.xml
|               |   |   ServiceFabricNodeBootstrapAgent.exe.config
|               |   |   ThirdPartyNotices.txt
|               |   |   VERSION.txt
|               |   |   
|               |   \---ProductPackage
|               +---Status
|               |       HeartBeat.Json
|               |       
|               \---UpgradeService
|                       Checksum.txt
|                       current.config
|                       ServiceFabricNodeBootstrapUpgradeAgent.exe.config
|                       ThirdPartyNotices.txt
|                       VERSION.txt
|                       
+---SvcFab
|   |   clusterManifest.xml
|   |   FabricHostSettings.xml
|   |   
|   +---IB
|   +---ImageBuilderProxy
|   +---Log
|   |   +---AppInstanceData
|   |   |   +---Etl
|   |   |   \---Table
|   |   +---ApplicationCrashDumps
|   |   +---ArchivedOperationalTraces
|   |   +---ArchivedQueryTraces
|   |   +---ArchivedTraces
|   |   +---Containers
|   |   +---CrashDumps
|   |   +---OperationalTraces
|   |   +---PerformanceCountersBinary
|   |   +---PerformanceCountersBinaryArchive
|   |   +---PerformanceCounters_ServiceFabricPerfCounter
|   |   +---QueryTraces
|   |   +---Traces
|   |   \---work
|   |       +---0
|   |       |   \---0
|   |       +---temp
|   |       +---WFab
|   |       |   +---0
|   |       |   |   +---0
|   |       |   |   |   \---Log
|   |       |   |   |       +---Bootstrap
|   |       |   |   |       +---Fabric
|   |       |   |   |       \---Lease
|   |       |   |   \---1
|   |       |   |       \---AFU
|   |       |   |           \---LMap
|   |       |   |               +---Bootstrap
|   |       |   |               +---Fabric
|   |       |   |               \---Lease
|   |       |   +---1
|   |       |   |   \---0
|   |       |   |       \---AFU
|   |       |   |           \---LMap
|   |       |   \---2
|   |       |       \---0
|   |       |           \---AFU
|   |       |               \---LMap
|   |       +---WFDynMan
|   |       \---WFEtwMan
|   +---ReplicatorLog
|   +---_App
|   |   \---__FabricSystem_App4294967295
|   |       |   App.1.0.xml
|   |       |   BRS.Manifest.Current.xml
|   |       |   BRS.Package.1.0.xml
|   |       |   DnsService.Manifest.Current.xml
|   |       |   DnsService.Package.1.0.xml
|   |       |   FAS.Manifest.Current.xml
|   |       |   FAS.Package.1.0.xml
|   |       |   FAS.Package.Current.xml
|   |       |   FileStoreService.Manifest.Current.xml
|   |       |   FileStoreService.Package.1.0.xml
|   |       |   FileStoreService.Package.Current.xml
|   |       |   IS.Manifest.Current.xml
|   |       |   IS.Package.1.0.xml
|   |       |   RM.Manifest.Current.xml
|   |       |   RM.Package.1.0.xml
|   |       |   RMS.Manifest.Current.xml
|   |       |   RMS.Package.1.0.xml
|   |       |   TVS.Manifest.Current.xml
|   |       |   TVS.Package.1.0.xml
|   |       |   UOS.Manifest.Current.xml
|   |       |   UOS.Package.1.0.xml
|   |       |   US.Manifest.Current.xml
|   |       |   US.Package.1.0.xml
|   |       |   US.Package.Current.xml
|   |       |   
|   |       +---BRS.Code.Current
|   |       +---DnsService.Code.Current
|   |       +---FAS.Code.Current
|   |       +---FileStoreService.Code.Current
|   |       +---IS.Code.Current
|   |       +---log
|   |       +---RM.Code.Current
|   |       +---RMS.Code.Current
|   |       +---temp
|   |       +---TVS.Code.Current
|   |       +---UOS.Code.Current
|   |       +---US.Code.Current
|   |       \---work
|   |           +---00000000000000000000000000005000_131819617113459839_131819617332559082
|   |           +---00000000000000000000000000005000_131819617113459839_131819617333180865
|   |           +---00000000000000000000000000005000_131819617113459839_131819617336462127
|   |           +---00000000000000000000000000005000_131819617113459839_131819617336462128
|   |           +---00000000000000000000000000005000_131819617113459839_131819617336618359
|   |           +---00000000000000000000000000005000_131819617113459839_131819617336618360
|   |           +---00000000000000000000000000005000_131819617113459839_131819617339118347
|   |           +---00000000000000000000000000005000_131819617113459839_131819617339118348
|   |           +---00000000000000000000000000005000_131819617113459839_131819617341305969
|   |           +---00000000000000000000000000005000_131819617113459839_131819617341305970
|   |           +---00000000000000000000000000005000_131819617113459839_131819653339122794
|   |           +---00000000000000000000000000005000_131819617113459839_131819653339122795
|   |           +---00000000000000000000000000005000_131819617113459839_131819653339278925
|   |           +---00000000000000000000000000005000_131819617113459839_131819653339278926
|   |           +---FS
|   |           |   \---P_00000000-0000-0000-0000-000000003000
|   |           |       \---R_131819617111897350
|   |           +---P_51b3d66d-275d-43c6-b668-7a5f33b5386b
|   |           |   \---R_131819617170022352
|   |           +---Staging
|   |           |   \---131819617111897350
|   |           |       \---960b0369-682a-4d0d-b241-b541e902091d
|   |           \---Store
|   |               \---131819617111897350
|   |                   +---6.3.176.9494_1
|   |                   |       131819616815894166_8589934592_1.ClusterManifest.xml
|   |                   |       
|   |                   \---WindowsFabricStore
|   |                           131819616815894166_8589934592_4.ClusterManifest.1.xml
|   |                           
|   \---_nt0_0
|       \---Fabric
|           |   ClusterManifest.1.xml
|           |   ClusterManifest.current.xml
|           |   Fabric.Package.1.0.xml
|           |   Fabric.Package.1.1.xml
|           |   Fabric.Package.current.xml
|           |   
|           +---Fabric.Config.1.0
|           |       Settings.xml
|           |       
|           +---Fabric.Config.1.131819617921315472
|           |       Settings.xml
|           |       
|           +---Fabric.Data
|           |       InfrastructureManifest.xml
|           |       
|           \---work
|               +---CM
|               |   \---P_00000000-0000-0000-0000-000000002000
|               |       \---R_131819617111897350
|               +---EventsReaderTmpOutput
|               +---FileTransfer
|               +---FM
|               |   \---P_00000000-0000-0000-0000-000000000001
|               |       \---R_131819616751206190
|               +---ImageCache
|               +---NS
|               |   +---P_00000000-0000-0000-0000-000000001000
|               |   |   \---R_131819617111897350
|               |   +---P_00000000-0000-0000-0000-000000001001
|               |   |   \---R_131819617111897350
|               |   \---P_00000000-0000-0000-0000-000000001002
|               |       \---R_131819617111897350
|               \---RA
\---windowsAzure
    +---Applications
    +---CollectGuestLogsTemp
    |       629c62ef-f008-44a0-9269-11c2037fd69f.zip.json
    |       
    +---Config
    |       f23968ac-9066-43da-863c-2d4ab096c18f.f23968ac-9066-43da-863c-2d4ab096c18f._nt0_0.1.xml
    |       
    +---Logs
    |   |   AgentRuntime.log
    |   |   MonitoringAgent.log
    |   |   NetAgent-2018.09.20-23.59.28.503.log
    |   |   Telemetry.log
    |   |   TransparentInstaller.log
    |   |   WaAppAgent.log
    |   |   
    |   +---AggregateStatus
    |   |       aggregatestatus.json
    |   |       aggregatestatus_20180921025640005.json
    |   |       aggregatestatus_20180921025655241.json
    |   |       aggregatestatus_20180921025710266.json
    |   |       aggregatestatus_20180921025725363.json
    |   |       aggregatestatus_20180921025740457.json
    |   |       aggregatestatus_20180921025755488.json
    |   |       aggregatestatus_20180921025810519.json
    |   |       aggregatestatus_20180921025825550.json
    |   |       aggregatestatus_20180921025840582.json
    |   |       aggregatestatus_20180921025855629.json
    |   |       
    |   +---Plugins
    |   |   +---Microsoft.Azure.Diagnostics.IaaSDiagnostics
    |   |   |   \---1.11.3.12
    |   |   |       |   CommandExecution.log
    |   |   |       |   CommandExecution_20180921000112370.log
    |   |   |       |   DiagnosticsPlugin.log
    |   |   |       |   DiagnosticsPluginLauncher.log
    |   |   |       |   
    |   |   |       \---WAD0107
    |   |   |           +---Configuration
    |   |   |           |       Checkpoint.txt
    |   |   |           |       EventSource_Manifest_13c2a97d-71da-5ab5-47cb-1497aec602e1_Pid_2704.xml
    |   |   |           |       EventSource_Manifest_13c2a97d-71da-5ab5-47cb-1497aec602e1_Ver_11.backup.xml
    |   |   |           |       EventSource_Manifest_13c2a97d-71da-5ab5-47cb-1497aec602e1_Ver_11.xml
    |   |   |           |       MaConfig.xml
    |   |   |           |       MonAgentHost.1.log
    |   |   |           |       
    |   |   |           +---Package
    |   |   |           |   \---Agent
    |   |   |           +---Packets
    |   |   |           +---Status
    |   |   |           \---Tables
    |   |   \---Microsoft.Azure.ServiceFabric.ServiceFabricNode
    |   |       \---1.1.0.2
    |   |               CommandExecution.log
    |   |               CommandExecution_20180920235941450.log
    |   |               InfrastructureManifest.xml
    |   |               TempClusterManifest.xml
    |   |               VCRuntimeInstall-20180920235850548.log
    |   |               VCRuntimeInstall-20180920235850548_0_vcRuntimeMinimum_x64.log
    |   |               VCRuntimeInstall-20180920235850548_1_vcRuntimeAdditional_x64.log
    |   |               VCRuntimeInstall-20180920235938349.log
    |   |               VCRuntimeInstall-20180920235938349_000_vcRuntimeMinimum_x64.log
    |   |               VCRuntimeInstall-20180920235938349_001_vcRuntimeAdditional_x64.log
    |   |               
    |   \---VFPlugin
    |           VFPlugin-2018.09.20-23.59.29.143.log
    |           
    +---Packages
    |   |   CollectVMHealth.exe.config
    |   |   CommonAgentConfig.config
    |   |   PackageInformation.txt
    |   |   TransparentInstaller.dll.config
    |   |   WaAppAgent.exe.config
    |   |   
    |   +---GuestAgent
    |   |   |   IISConfigurator-Ipv4only.exe.config
    |   |   |   IISConfigurator-Ipv6andIpv4.exe.config
    |   |   |   IpAddressAssignment.exe.config
    |   |   |   ProviderGuids.txt
    |   |   |   WindowsAzureGuestAgent.exe.config
    |   |   |   
    |   |   \---FindVolume
    |   |           DATALOSS_WARNING_README.txt
    |   |           
    |   \---Telemetry
    |           WindowsAzureTelemetryService.exe.config
    |           
    \---WindowsAzureNetAgent_1.0.0.118
        |   HandlerEnvironment.json
        |   
        \---WindowsAzureNetAgent
            +---Plugins
            |   \---VFPlugin
            |       |   manifest.xml
            |       |   
            |       \---Code
            \---RuntimeSettings
                    0.settings
                    

PS C:\temp> 
```