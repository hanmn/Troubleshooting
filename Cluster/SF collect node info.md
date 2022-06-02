# Collecting Service Fabric Windows node diagnostics data

When working with Microsoft support on a Service Fabric Windows cluster issue, it may be necessary to capture additional diagnostics information from one or more nodes in the cluster. 

## Default diagnostic information script will collect:
**NOTE: All of these options except Service Fabric can be disabled using switch arguments when running script.**
- Windows Event Logs - System, Application, Firewall, Http, Service Fabric
- Operating System information
    - Drive configuration
    - Directory list of 'MachineKeys' folder
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
    (new-object net.webclient).downloadfile("https://raw.githubusercontent.com/Service-Fabric-Troubleshooting-Guides/master/S
    cripts/sf-collect-node-info.ps1");
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

NAME
    G:\github\Service-Fabric-Troubleshooting-Guides\Scripts\sf-collect-node-info.ps1

SYNOPSIS
    powershell script to collect service fabric node diagnostic data

    To download and execute, run the following commands on each sf node in admin powershell:
    iwr('https://raw.githubusercontent.com/Service-Fabric-Troubleshooting-Guides/master/Scripts/sf-collect-node-info.ps1')
    -UseBasicParsing|iex

    To download and execute with arguments:
    (new-object net.webclient).downloadfile("https://raw.githubusercontent.com/Service-Fabric-Troubleshooting-Guides/master/S
    cripts/sf-collect-node-info.ps1");
    .\sf-collect-node-info.ps1 -certInfo -remoteMachines 10.0.0.4,10.0.0.5,10.0.0.6,10.0.0.7,10.0.0.8

    upload to workspace sfgather* dir or zip


SYNTAX
    G:\github\Service-Fabric-Troubleshooting-Guides\Scripts\sf-collect-node-info.ps1 [[-workdir] <String>] [[-eventLogNames]
    <String>] [[-externalUrl] <String>] [[-startTime] <DateTime>] [[-endTime] <DateTime>] [[-networkTestAddress] <String>]
    [[-perfmonMin] <Int32>] [[-timeoutMinutes] <Int32>] [[-apiversion] <String>] [[-ports] <Int32[]>] [[-remoteMachines]
    <String[]>] [-noAdmin] [-noEventLogs] [-noOs] [-noNet] [-certInfo] [-quiet] [-modifyFirewall] [<CommonParameters>]


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

    -networkTestAddress <String>
        remote machine for service fabric tcp port test.

        Required?                    false
        Position?                    6
        Default value                $env:computername
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -perfmonMin <Int32>
        minutes to run basic perfmon at end of collection after all jobs run.
        cpu, memory, disk, network.

        Required?                    false
        Position?                    7
        Default value                0
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -timeoutMinutes <Int32>
        script timeout in minutes.
        script will cancel any running jobs and collect what is available if timeout is hit.

        Required?                    false
        Position?                    8
        Default value                $perfmonMin + 15
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -apiversion <String>
        api version for testing fabricgateway endpoint with service fabric rest api calls.

        Required?                    false
        Position?                    9
        Default value                6.2-preview
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -ports <Int32[]>
        comma separated list of tcp ports to test.
        default ports include basic connectivity, rdp, and service fabric.

        Required?                    false
        Position?                    10
        Default value                @(1025, 1026, 19000, 19080, 135, 445, 3389, 5985)
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -remoteMachines <String[]>
        comma separated list of machine names and / or ip addresses to run diagnostic script on remotely.
        this will only work if proper connectivity, authentication, and OS health exists.
        if there are errors connecting, run script instead individually on each node.
        to resolve remote connectivity issues, verify tcp port connectivity for ports, review, winrm, firewall, and nsg
        configurations.

        Required?                    false
        Position?                    11
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

    -certInfo [<SwitchParameter>]
        switch to enable collection of certificate store export to troubleshoot certificate issues.
        thumbprints and serial numbers during export will be partially masked.

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

    -modifyFirewall [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value                False
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





RELATED LINKS
    https://raw.githubusercontent.com/Service-Fabric-Troubleshooting-Guides/master/Scripts/sf-collect-node-info.ps1
