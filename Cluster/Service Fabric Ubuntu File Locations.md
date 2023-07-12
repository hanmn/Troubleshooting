# Service Fabric Ubuntu File Locations

[Service Fabric Core File Locations](#Service-Fabric-Core-File-Locations)  
[Service Fabric Event Logs](#Service-Fabric-Event-Logs)  
[Guest Agent Logs](#Guest-Agent-Logs)  
[Service Fabric Extension Plugin](#Service-Fabric-Extension-Plugin)  
[Docker Daemon Logs](#Docker-Daemon-Logs)  

**The tables below list file locations for Service Fabric on Ubuntu.**

## Service Fabric Core File Locations

File Path | Content
----------|----------
/opt/microsoft/servicefabric/bin/Fabric/Fabric.Code/Fabric | default service fabric core code installation path
/mnt/sfroot | default application code, data, and log location
/mnt/sfroot/clusterManifest.xml | service fabric cluster manifest file
/mnt/sfroot/_App | default application code and data location
/mnt/sfroot/log | default service fabric diagnostic log path
/mnt/sfroot/log/CrashDumps | service fabric (fabric*.exe) crash dump location
/mnt/sfroot/log/Traces | service fabric diagnostic trace temporary storage
/mnt/sfroot/< _node_name_# > | service fabric node configuration data path

## Service Fabric Event Logs

File Path | Content
----------|----------
var/log/syslog | linux system event log
var/log/sfnode/sfnodelog | service fabric application event log

## Guest Agent Logs

File Path | Content
----------|----------
/var/log/waagent.log | azure agent log

## Service Fabric Extension Plugin

File Path | Content
----------|----------
var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-1.1.0.2 | service fabric extension download, configuration, and status
/var/log/azure/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode TempClusterManifest.xml | service fabric cluster configuration
var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-1.1.0.2/config/0.settings | service fabric extension configuration
var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-1.1.0.2/config/0.status | service fabric extension installation status
var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-1.1.0.2/heartbeat.log | service fabric node status
var/lib/waagent/Microsoft.Azure.ServiceFabric.ServiceFabricLinuxNode-1.1.0.2/ServiceFabricLinuxExtension_install.log | service fabric extension installation log

## Docker Daemon Logs

File Path | Content
----------|----------
journalctl -u docker.service | command to enumerate docker daemon logs