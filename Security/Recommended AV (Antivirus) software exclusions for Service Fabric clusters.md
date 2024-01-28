# Recommended AV (Antivirus) software exclusions for Service Fabric clusters

## **Exclude the following Service Fabric components from Antivirus**

- FabricDeployer.exe
- FabricSetup.exe
- FabricInstallerService.exe
- FabricHost.exe
- Fabric.exe
- FabricDCA.exe
- FabricGateway.exe
- FabricUS.exe
- FabricFAS.exe
- FileStoreService.exe
- FabricRM.exe
- FabricApplicationGateway.exe
- FabricUOS.exe
- ImageBuilder.exe

## **Exclude the following directories and subdirectories from Antivirus**

- Service Fabric installation directory - C:\Program Files\\Microsoft Service Fabric
- Service Fabric data directory - FabricDataRoot  
  - Azure cluster default - D:\SvcFab  
  - Standalone cluster default - C:\ProgramData\SF  
- Service Fabric log directory - FabricLogRoot  
  - Azure cluster default - D:\SvcFab\Log  
  - Standalone cluster default - C:\ProgramData\SF\Log  

### **Docker container directory exclusion**

From: https://docs.docker.com/engine/security/antivirus/  
When antivirus software scans files used by Docker, these files may be locked in a way that causes Docker commands to hang.

One way to reduce these problems is to add the Docker data directory (/var/lib/docker on Linux, %ProgramData%\docker on Windows Server, or $HOME/Library/Containers/com.docker.docker/ on Mac) to the antivirus’s exclusion list. However, this comes with the trade-off that viruses or malware in Docker images, writable layers of containers, or volumes are not detected. If you do choose to exclude Docker’s data directory from background virus scanning, you may want to schedule a recurring task that stops Docker, scans the data directory, and restarts Docker.  

## ARM Template example  

One method of configuring exclusions for Azure clusters would be to use the [Iaas Antimalware extension](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/iaas-antimalware-windows).

Example json for configuring Antimalware on a vm scaleset node for service fabric in 'extensions' section under 'extensionProfile':  

**NOTE: This will override any existing configuration. Be sure to merge existing Windows Defender / IaaS Antimalware settings with below before deploying.**  

```json
//"extensionProfile": {
    //"extensions": [
        {
            "name": "IaaSAntimalware",
            "properties": {
                "autoUpgradeMinorVersion": false,
                "publisher": "Microsoft.Azure.Security",
                "type": "IaaSAntimalware",
                "typeHandlerVersion": "1.5",
                "settings": {
                    "AntimalwareEnabled": "true",
                    "Exclusions": {
                        "Extensions": "",
                        "Paths": "%ProgramData%\\Docker;%ProgramFiles%\\Microsoft Service Fabric\\bin;D:\\SvcFab",
                        "Processes": ""
                    },
                    "RealtimeProtectionEnabled": "true",
                    "ScheduledScanSettings": {
                        "isEnabled": "true",
                        "scanType": "Quick",
                        "day": "7",
                        "time": "120"
                    }
                },
                "protectedSettings": null
            }
        }
    //]
//}
```

### Powershell example

Powershell is another method useful for standalone and server core clusters.  
Run the following from an admin powershell prompt on node to set example folder exclusions:  

**NOTE: This will override any existing configuration. Be sure to merge existing Windows Defender / IaaS Antimalware settings with below before executing.**  

```powershell
Set-MpPreference -ExclusionPath D:\SvcFab, "%ProgramData%\Docker", "%ProgramFiles%\Microsoft Service Fabric\bin"
```

## Verification

```text
PS C:\programdata\docker> Get-MpPreference


AttackSurfaceReductionOnlyExclusions          : 
AttackSurfaceReductionRules_Actions           : 
AttackSurfaceReductionRules_Ids               : 
CheckForSignaturesBeforeRunningScan           : False
CloudBlockLevel                               : 0
CloudExtendedTimeout                          : 0
ComputerID                                    : 12C8CC2C-2BAF-4ADA-B48F-437318E40D8F
ControlledFolderAccessAllowedApplications     : 
ControlledFolderAccessProtectedFolders        : 
DisableArchiveScanning                        : False
DisableAutoExclusions                         : False
DisableBehaviorMonitoring                     : False
DisableBlockAtFirstSeen                       : False
DisableCatchupFullScan                        : True
DisableCatchupQuickScan                       : True
DisableEmailScanning                          : True
DisableIntrusionPreventionSystem              : 
DisableIOAVProtection                         : False
DisablePrivacyMode                            : False
DisableRealtimeMonitoring                     : False
DisableRemovableDriveScanning                 : True
DisableRestorePoint                           : True
DisableScanningMappedNetworkDrivesForFullScan : True
DisableScanningNetworkFiles                   : False
DisableScriptScanning                         : False
EnableControlledFolderAccess                  : 0
EnableFileHashComputation                     : False
EnableLowCpuPriority                          : False
EnableNetworkProtection                       : 0
ExclusionExtension                            : 
ExclusionPath                                 : {%ProgramData%\Docker, %ProgramFiles%\Microsoft Service Fabric\bin, D:\SvcFab}
ExclusionProcess                              : 
HighThreatDefaultAction                       : 0
LowThreatDefaultAction                        : 0
MAPSReporting                                 : 2
MeteredConnectionUpdates                      : False
ModerateThreatDefaultAction                   : 0
PUAProtection                                 : 0
QuarantinePurgeItemsAfterDelay                : 90
RandomizeScheduleTaskTimes                    : True
RealTimeScanDirection                         : 0
RemediationScheduleDay                        : 0
RemediationScheduleTime                       : 02:00:00
ReportingAdditionalActionTimeOut              : 10080
ReportingCriticalFailureTimeOut               : 10080
ReportingNonCriticalTimeOut                   : 1440
ScanAvgCPULoadFactor                          : 50
ScanOnlyIfIdleEnabled                         : True
ScanParameters                                : 1
ScanPurgeItemsAfterDelay                      : 15
ScanScheduleDay                               : 7
ScanScheduleQuickScanTime                     : 00:00:00
ScanScheduleTime                              : 02:00:00
SevereThreatDefaultAction                     : 0
SharedSignaturesPath                          : 
SignatureAuGracePeriod                        : 0
SignatureDefinitionUpdateFileSharesSources    : 
SignatureDisableUpdateOnStartupWithoutEngine  : False
SignatureFallbackOrder                        : MicrosoftUpdateServer|MMPC
SignatureFirstAuGracePeriod                   : 120
SignatureScheduleDay                          : 8
SignatureScheduleTime                         : 01:45:00
SignatureUpdateCatchupInterval                : 1
SignatureUpdateInterval                       : 0
SubmitSamplesConsent                          : 1
ThreatIDDefaultAction_Actions                 : 
ThreatIDDefaultAction_Ids                     : 
UILockdown                                    : False
UnknownThreatDefaultAction                    : 0
PSComputerName                                : 
```

## Additional Information  

https://docs.microsoft.com/en-us/windows/security/threat-protection/microsoft-defender-antivirus/deploy-microsoft-defender-antivirus  
https://docs.microsoft.com/en-us/windows/security/threat-protection/microsoft-defender-antivirus/configure-server-exclusions-microsoft-defender-antivirus  
https://docs.microsoft.com/en-us/windows/security/threat-protection/microsoft-defender-antivirus/configure-extension-file-exclusions-microsoft-defender-antivirus  

https://docs.microsoft.com/en-us/windows-hardware/drivers/ifs/anti-virus-optimization-for-windows-containers  
https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-faq  
