<#
.SYNOPSIS
powershell script to collect service fabric node diagnostic data

To download and execute, run the following commands on each sf node in admin powershell:
iwr('https://raw.githubusercontent.com/Service-Fabric-Troubleshooting-Guides/master/Scripts/sf-collect-node-info.ps1') -UseBasicParsing|iex

To download and execute with arguments:
(new-object net.webclient).downloadfile("https://raw.githubusercontent.com/Service-Fabric-Troubleshooting-Guides/master/Scripts/sf-collect-node-info.ps1");
.\sf-collect-node-info.ps1 -certInfo -remoteMachines 10.0.0.4,10.0.0.5,10.0.0.6,10.0.0.7,10.0.0.8

upload to workspace sfgather* dir or zip

.DESCRIPTION
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
    
.NOTES
    File Name  : sf-collect-node-info.ps1
    Author     : microsoft service fabric support
    Version    : 180904 original
    History    : 

.EXAMPLE
    .\sf-collect-node-info.ps1
    default command to collect event logs, process, service, os information for last 7 days.

.EXAMPLE
    .\sf-collect-node-info.ps1 -certInfo
    example command to query all diagnostic information, event logs, and certificate store information.

.EXAMPLE
    .\sf-collect-node-info.ps1 -startTime 8/16/2018
    example command to query all diagnostic information using start date of 08/16/2018.
    dates are used for event log and rest queries

.EXAMPLE
    .\sf-collect-node-info.ps1 -remoteMachines 10.0.0.4,10.0.0.5
    example command to query diagnostic information remotely from two machines.
    files will be copied back to machine where script is being executed.

.EXAMPLE
    .\sf-collect-node-info.ps1 -runCommand "dir c:\windows -recurse"
    example to run custom command on machine after data collection
    output will be captured in runCommand.txt

.PARAMETER apiVersion
    api version for testing fabricgateway endpoint with service fabric rest api calls.

.PARAMETER certInfo
    switch to enable collection of certificate store export to troubleshoot certificate issues.
    thumbprints and serial numbers during export will be partially masked.

.PARAMETER endTime
    end time in normal dateTime formatting.
    example "8/26/2018 22:00"
    default today.

.PARAMETER eventLogNames
    regex list of eventlog names to export into csv formatl
    default list should be sufficient for most scenarios.

.PARAMETER externalUrl
    url to use for network connectivity tests.

.PARAMETER netmonMin
    minutes to run network trace at end of collection after all jobs run.

.PARAMETER networkTestAddress
    remote machine for service fabric tcp port test.

.PARAMETER noAdmin
    switch to bypass admin powershell session check.
    most jobs will work with non-admin session but not all for example some of the network tests.

.PARAMETER noEventLogs
    switch to prevent download of event-log-manager.ps1 script and collection of windows event log events.

.PARAMETER noNet
    bypass network tests.

.PARAMETER noOs
    bypass OS information collection.

.PARAMETER noSF
    bypass service fabric information collection.

.PARAMETER perfmonMin
    minutes to run basic perfmon at end of collection after all jobs run.
    cpu, memory, disk, network.

.PARAMETER ports
    comma separated list of tcp ports to test.
    default ports include basic connectivity, rdp, and service fabric.

.PARAMETER quiet
    disable display of folder / zip in shell at end of script.

.PARAMETER remoteMachines
    comma separated list of machine names and / or ip addresses to run diagnostic script on remotely.
    this will only work if proper connectivity, authentication, and OS health exists.
    if there are errors connecting, run script instead individually on each node.
    to resolve remote connectivity issues, verify tcp port connectivity for ports, review, winrm, firewall, and nsg configurations.

.PARAMETER runCommand
    command to run at end of collection.
    command needs to runnable from 'invoke-expression'

.PARAMETER startTime
    start time in normal dateTime formatting.
    example "8/26/2018 22:00"
    default -7 days.

.PARAMETER timeoutMinutes
    script timeout in minutes.
    script will cancel any running jobs and collect what is available if timeout is hit.

.PARAMETER workDir
    output directory where all files will be created.
    default is $env:temp

.LINK
    https://raw.githubusercontent.com/Service-Fabric-Troubleshooting-Guides/master/Scripts/sf-collect-node-info.ps1
#>
[CmdletBinding()]
param(
    [string]$workdir,
    [switch]$certInfo,
    [string]$eventLogNames = "System$|Application$|wininet|dns|Fabric|http|Firewall|Azure",
    [string]$externalUrl = "bing.com",
    [dateTime]$startTime = (get-date).AddDays(-7),
    [dateTime]$endTime = (get-date),
    [switch]$modifyFirewall,
    [int]$netmonMin,
    [string]$networkTestAddress = $env:computername,
    [int]$perfmonMin,
    [int]$timeoutMinutes = [Math]::Max($perfmonMin,$netmonMin) + 15,
    [string]$apiversion = "6.2-preview", #"6.0"
    [int[]]$ports = @(1025, 1026, 19000, 19080, 135, 445, 3389, 5985),
    [string[]]$remoteMachines,
    [switch]$noAdmin,
    [switch]$noEventLogs,
    [switch]$noOs,
    [switch]$noNet,
    [switch]$noSF,
    [switch]$quiet,
    [string]$runCommand
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$timer = get-date
$scriptUrl = 'https://raw.githubusercontent.com/Service-Fabric-Troubleshooting-Guides/master/Scripts/sf-collect-node-info.ps1'
$currentWorkDir = get-location
$osVersion = [version]([string]((wmic os get Version) -match "\d"))
$legacy = ($osVersion.major -lt 10)
$parentWorkDir = $null
$jobs = new-object collections.arraylist
$logFile = $Null
$global:zipFile = $null
$trustedHosts = $Null
$winrmClientInfo = $Null
$eventScriptFile = $Null
$sfCollectInfoDir = "sfColInfo-"
$restTimeoutSec = 15
$serviceFabricInstallReg = "HKLM:\software\microsoft\service fabric"
$warnonZoneCrossingReg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$disableWarnOnZoneCrossing = $false
$firewallsDisabled = $false

# to bypass self-signed cert validation check
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;

public class IDontCarePolicy : ICertificatePolicy {
        public IDontCarePolicy() {}
        public bool CheckValidationResult(
        ServicePoint sPoint, X509Certificate cert,
        WebRequest wRequest, int certProb) {
        return true;
    }
}
"@

[System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy 

function main()
{
    $error.Clear()
    write-warning "to troubleshoot this issue, this script may collect sensitive information similar to other microsoft diagnostic tools."
    write-warning "information may contain items such as ip addresses, process information, user names, or similar."
    write-warning "information in directory / zip can be reviewed before uploading to workspace."
    write-warning "see: https://github.com/Azure/Service-Fabric-Troubleshooting-Guides/blob/master/Cluster/SF%20collect%20node%20info.md"

    if (!$workDir -and $remoteMachines)
    {
        $workdir = "$($env:temp)\$($sfCollectInfoDir)$((get-date).ToString("yy-MM-dd-HH-mm"))"
    }
    elseif (!$workDir)
    {
        $workdir = "$($env:temp)\$($sfCollectInfoDir)$($env:COMPUTERNAME)"
    }

    $parentWorkDir = [io.path]::GetDirectoryName($workDir)
    $eventScriptFile = "$($parentWorkdir)\event-log-manager.ps1"

    if ((test-path $workdir))
    {
        remove-item $workdir -Recurse -Force
    }

    new-item $workdir -ItemType Directory
    Set-Location $parentworkdir
    $logFile = "$($workdir)\sf-collect-node-info.log"
    Start-Transcript -Path $logFile -Force
    write-host "starting $(get-date)"

    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {   
        Write-Warning "please restart script in administrator powershell session"

        if (!$noadmin)
        {
            Write-Warning "if unable to run as admin, restart and use -noadmin switch. This will collect less data that may be needed. exiting..."
            return $false
        }
    }

    
    $disableSecuritySetting = (Get-ItemProperty -Path $warnonZoneCrossingReg -Name "WarnonZoneCrossing")
    if (!$disableSecuritySetting -or $disableSecuritySetting.WarnonZoneCrossing -eq 1)
    {
        New-ItemProperty -Path $warnonZoneCrossingReg -Name "WarnonZoneCrossing" -Value 0 -PropertyType DWORD -Force | Out-Null
        $disableWarnOnZoneCrossing = $true
    }

    write-host "remove old jobs"
    get-job | remove-job -Force

    # stage event-log-manager script
    if (!$noEventLogs -and !(test-path $eventScriptFile))
    {
        (new-object net.webclient).downloadfile("http://aka.ms/event-log-manager.ps1", $eventScriptFile)
    }

    if ($remoteMachines)
    {
        # setup local (source) machine for best chance of success
        $winrmClientInfo = (winrm get winrm/config/client)
        $trustedHostsPattern = "TrustedHosts = (.*)"
        
        if ([regex]::IsMatch($winrmClientInfo, $trustedHostsPattern))
        {
            $trustedHosts = ([regex]::matches($winrmClientInfo , $trustedHostsPattern)).groups[1].value
        }

        winrm set winrm/config/client '@{TrustedHosts="*"}'

        # switch to arraylist
        $remoteMachines = new-object collections.arraylist(, $remoteMachines)

        foreach ($machine in (new-object collections.arraylist(, $remoteMachines)))
        {
            $adminPath = "\\$($machine)\admin$\temp"

            if (!(Test-path $adminPath) -and $modifyFirewall)
            {
                write-warning "unable to connect to remote machine $($machine). attempting to disable firewall remotely..."
                Invoke-Command -ComputerName $machine -ScriptBlock { Set-NetFirewallProfile -Profile Public -Enabled False } 
                $firewallsDisabled = $true
            }

            if (!(Test-path $adminPath))
            {
                Write-Warning "unable to connect to $($machine) to start diagnostics. skipping!"
                $remoteMachines.Remove($machine)
                continue
            }

            if (!$noEventLogs)
            {
                copy-item -path $eventScriptFile -Destination $adminPath -force
            }

            copy-item -path ($MyInvocation.ScriptName) -Destination $adminPath -force

            write-host "adding job for $($machine)"
            [void]$jobs.Add((Invoke-Command -JobName $machine -AsJob -ComputerName $machine -scriptblock {
                        param($scriptUrl = $args[0], $machine = $args[1], $networkTestAddress = $args[2], $certInfo = $args[3], $sfCollectInfoDir = $args[4])
                        $parentWorkDir = "$($env:systemroot)\temp"
                        $workDir = "$($parentWorkDir)\$($sfCollectInfoDir)$($machine)"
                        $scriptPath = "$($parentWorkDir)\$($scriptUrl -replace `".*/`",`"`")"
                
                        if ($certInfo)
                        {
                            $certInfo = "-certInfo "
                        }
                        else
                        {
                            $certInfo = ""
                        }

                        if (!(test-path $scriptPath))
                        {
                            (new-object net.webclient).downloadfile($scriptUrl, $scriptPath)
                        }
             
                        start-process -filepath "powershell.exe" -ArgumentList "-File $($scriptPath) $($certInfo)-quiet -noadmin -networkTestAddress $($networkTestAddress) -workDir $($workDir)" -Wait -NoNewWindow
                        write-host ($error | out-string)
                    } -ArgumentList @($scriptUrl, $machine, $networkTestAddress, $certInfo, $sfCollectInfoDir)))
        }

        monitor-jobs

        foreach ($machine in $remoteMachines)
        {
            $adminPath = "\\$($machine)\admin$\temp"
            $foundZip = $false

            if (!(Test-path $adminPath))
            {
                Write-Warning "unable to connect to $($machine) to copy zip. skipping!"
                continue
            }

            $sourcePath = "$($adminPath)\$($sfCollectInfoDir)$($machine)"
            $destPath = "$($workDir)\$($sfCollectInfoDir)$($machine)"

            $sourcePathZip = "$($sourcePath).zip"
            $destPathZip = "$($destPath).zip"

            if ((test-path $sourcePathZip))
            {
                write-host "copying file $($sourcePathZip) to $($destPathZip)" -ForegroundColor Magenta
                Copy-Item $sourcePathZip $destPathZip -Force
                remove-item $sourcePathZip -Force
                $foundZip = $true
            }
            
            if ((test-path $sourcePath))
            {
                if (!$foundZip)
                {
                    write-host "copying folder $($sourcePath) to $($destPath)" -ForegroundColor Magenta
                    Copy-Item $sourcePath $destPath -Force -Recurse
                    compress-file $destPath
                    remove-item $destPath -Recurse -Force
                }

                remove-item $sourcePath -Recurse -Force
            }
            else
            {
                write-host "warning: unable to find diagnostic files in $($sourcePath)"
            }

            if ($firewallsDisabled)
            {
                write-host "re-enabling firewall on $($machine)"
                Invoke-Command -ComputerName $machine -ScriptBlock { Set-NetFirewallProfile -Profile Public -Enabled True } 
            }
        }

        $global:zipFile = compress-file $workDir
    }
    else
    {
        process-machine
    }

    if (!($quiet) -and (test-path "$($env:systemroot)\explorer.exe"))
    {
        start-process "explorer.exe" -ArgumentList $parentWorkDir
    }
}

function process-machine()
{
    write-host "processing machine"
    
    if (!$legacy)
    {
        add-job -jobName "windows update" -scriptBlock {
            param($workdir = $args[0]) 
            Get-WindowsUpdateLog -LogPath "$($workdir)\windowsupdate.log.txt"
        } -arguments $workdir
    }
    else
    {
        copy-item "$env:systemroot\windowsupdate.log" "$($workdir)\windowsupdate.log.txt"
    }

    if (!$noEventLogs)
    {
        add-job -jobName "event logs" -scriptBlock {
            param($workdir = $args[0], $parentWorkdir = $args[1], $eventLogNames = $args[2], $startTime = $args[3], $endTime = $args[4], $eventScriptFile = $args[5])
            $eventScriptFile = "$($parentWorkdir)\event-log-manager.ps1"
            if (!(test-path $eventScriptFile))
            {
                (new-object net.webclient).downloadfile("http://aka.ms/event-log-manager.ps1", $eventScriptFile)
            }

            $tempLocation = "$($workdir)\event-logs"
            if (!(test-path $tempLocation))
            {
                New-Item -ItemType Directory -Path $tempLocation    
            }

            $argList = "-File $($parentWorkdir)\event-log-manager.ps1 -eventLogNamePattern `"$($eventlognames)`" -eventStartTime `"$($startTime)`" -eventStopTime `"$($endTime)`" -eventDetails -merge -uploadDir `"$($tempLocation)`" -nodynamicpath"
            write-host "event logs: starting command powershell.exe $($argList)"
            start-process -filepath "powershell.exe" -ArgumentList $argList -Wait -WindowStyle Hidden -WorkingDirectory $tempLocation
        } -arguments @($workdir, $parentWorkdir, $eventLogNames, $startTime, $endTime, $eventScriptFile)
    }

    if(!$noOs)
    {
        add-job -jobName "check machinekeys" -scriptBlock {
            param($workdir = $args[0])
            $machineKeys = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys"
            Get-ChildItem $machineKeys -Recurse | out-file "$($workDir)\dir-machinekeys.txt"
            Invoke-Expression "icacls $($machineKeys) /C /T | out-file -Append $($workdir)\dir-machinekeys.txt"
        } -arguments @($workdir)

        add-job -jobName "check for dump file c" -scriptBlock {
            param($workdir = $args[0])
            get-childitem -Recurse -Path "c:\" -Filter "*.*dmp" | out-file "$($workdir)\dumplist-c.txt"
        } -arguments @($workdir)

        add-job -jobName "check for dump file d" -scriptBlock {
            param($workdir = $args[0])
            get-childitem -Recurse -Path "d:\" -Filter "*.*dmp" | out-file "$($workdir)\dumplist-d.txt"
        } -arguments @($workdir)

        add-job -jobName "drives" -scriptBlock {
            param($workdir = $args[0])
            Get-psdrive | out-file "$($workdir)\drives.txt"
        } -arguments @($workdir)
    
        add-job -jobName "os info" -scriptBlock {
            param($workdir = $args[0])
            get-wmiobject -Class Win32_OperatingSystem -Namespace root\cimv2 | format-list * | out-file "$($workdir)\os-info.txt"
            Invoke-Expression "cmd.exe /c sc query type= driver > $($workdir)\drivers.txt"
            get-hotfix | out-file "$($workdir)\hotfixes.txt"
            Get-process | out-file "$($workdir)\process-summary.txt"
            Get-process | format-list * | out-file "$($workdir)\processes.txt"
            get-process | Where-Object ProcessName -imatch "fabric" | out-file "$($workdir)\processes-fabric.txt"
            Get-service | out-file "$($workdir)\service-summary.txt"
            Get-Service | format-list * | out-file "$($workdir)\services.txt"
        } -arguments @($workdir)
    
        write-host "installed applications"
        Invoke-Expression "reg.exe query HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /s /v DisplayName > $($workDir)\installed-apps.reg.txt"
    
        write-host "features"
        Get-WindowsFeature | Where-Object "InstallState" -eq "Installed" | out-file "$($workdir)\windows-features.txt"
    
        add-job -jobName ".net reg" -scriptBlock {
            param($workdir = $args[0])
            Invoke-Expression "reg.exe query HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework /s > $($workDir)\dotnet.reg.txt"
        } -arguments @($workdir)
    
        write-host "policies"
        Invoke-Expression "reg.exe query HKEY_LOCAL_MACHINE\SOFTWARE\Policies /s > $($workDir)\policies.reg.txt"
    
        write-host "schannel"
        Invoke-Expression "reg.exe query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL /s > $($workDir)\schannel.reg.txt"
        
        add-job -jobName "azure config files" -scriptBlock {
            param($workdir = $args[0])
            function copy-files($sourceDir)
            {
                if (!(test-path $sourceDir))
                {
                    return
                }
                copy-item -path $sourceDir -Destination $workDir -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
                copy-item -path $sourceDir -Destination $workDir -Filter "*.txt" -Recurse -ErrorAction SilentlyContinue
                copy-item -path $sourceDir -Destination $workDir -Filter "*.settings" -Recurse -ErrorAction SilentlyContinue
                copy-item -path $sourceDir -Destination $workDir -Filter "*.config" -Recurse -ErrorAction SilentlyContinue
                copy-item -path $sourceDir -Destination $workDir -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue
                copy-item -path $sourceDir -Destination $workDir -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
            }
            copy-files "c:\packages"
            copy-files "c:\windowsAzure"
        } -arguments @($workdir)
    }

    if(!$noNet)
    {
        add-job -jobName "network port tests" -scriptBlock {
            param($workdir = $args[0], $networkTestAddress = $args[1], $ports = $args[2])
            foreach ($port in $ports)
            {
                $ProgressPreference = "silentlycontinue"
                test-netconnection -port $port -ComputerName $networkTestAddress -InformationLevel Detailed | out-file -Append "$($workdir)\network-port-test.txt"
            }
        } -arguments @($workdir, $networkTestAddress, $ports)

        add-job -jobName "check external connection" -scriptBlock {
            param($workdir = $args[0], $externalUrl = $args[1])
            [net.httpWebResponse](Invoke-WebRequest $externalUrl -UseBasicParsing).BaseResponse | out-file "$($workdir)\network-external-test.txt" 
        } -arguments @($workdir, $externalUrl)

        add-job -jobName "resolve-dnsname" -scriptBlock {
            param($workdir = $args[0], $networkTestAddress = $args[1], $externalUrl = $args[2])
            Resolve-DnsName -Name $networkTestAddress | out-file -Append "$($workdir)\resolve-dnsname.txt"
            Resolve-DnsName -Name $externalUrl | out-file -Append "$($workdir)\resolve-dnsname.txt"
        } -arguments @($workdir, $networkTestAddress, $externalUrl)

        add-job -jobName "nslookup" -scriptBlock {
            param($workdir = $args[0], $networkTestAddress = $args[1], $externalUrl = $args[2])
            write-host "nslookup"
            out-file -InputObject "querying nslookup for $($externalUrl)" -Append "$($workdir)\nslookup.txt"
            Invoke-Expression "nslookup $($externalUrl) | out-file -Append $($workdir)\nslookup.txt"
            out-file -InputObject "querying nslookup for $($networkTestAddress)" -Append "$($workdir)\nslookup.txt"
            Invoke-Expression "nslookup $($networkTestAddress) | out-file -Append $($workdir)\nslookup.txt"
        } -arguments @($workdir, $networkTestAddress, $externalUrl)

        if ((test-path "C:\Windows\System32\LogFiles\HTTPERR"))
        {
            write-host "http log files"
            copy-item -path "C:\Windows\System32\LogFiles\HTTPERR\*" -Destination $workdir -Force -Filter "*.log"
        }

        add-job -jobName "firewall" -scriptBlock {
            param($workdir = $args[0])
            Invoke-Expression "reg.exe query HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules /s > $($workDir)\firewallrules.reg.txt"
            Get-NetFirewallRule | out-file "$($workdir)\firewall-config.txt"
        } -arguments @($workdir)
    
        add-job -jobName "get-nettcpconnetion" -scriptBlock {
            param($workdir = $args[0])
            Get-NetTCPConnection | format-list * | out-file "$($workdir)\netTcpConnection.txt"
            Get-NetTCPConnection | Where-Object RemotePort -eq 1026 | out-file "$($workdir)\connected-nodes.txt"
        } -arguments @($workdir)

        write-host "netstat ports"
        Invoke-Expression "netstat -bna > $($workdir)\netstat.txt"

        write-host "netsh ssl"
        Invoke-Expression "netsh http show sslcert > $($workdir)\netshssl.txt"

        write-host "ip info"
        Invoke-Expression "ipconfig /all > $($workdir)\ipconfig.txt"
        write-host "winrm settings"
        Invoke-Expression "winrm get winrm/config/client > $($workdir)\winrm-config.txt" 
    }

    if ($certInfo)
    {
        write-host "certs (output scrubbed)"
        [regex]::Replace((Get-ChildItem -Path cert: -Recurse | format-list * | out-string), "[0-9a-fA-F]{20}`r`n", "xxxxxxxxxxxxxxxxxxxx`r`n") | out-file "$($workdir)\certs.txt"
    }
    
    #
    # service fabric information
    #
    if(!$noSF)
    {
        write-host "service fabric reg"
        Invoke-Expression "reg.exe query `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Service Fabric`" /s > $($workDir)\serviceFabric.reg.txt"
        Invoke-Expression "reg.exe query HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServiceFabricNodeBootStrapAgent /s > $($workDir)\serviceFabricNodeBootStrapAgent.reg.txt"

        if ((test-path $serviceFabricInstallReg))
        {
            enumerate-serviceFabric
        }
        else
        {
            write-warning "service fabric is *not* installed on this machine!"
        }
    }
    write-host "waiting for $($jobs.Count) jobs to complete"

    monitor-jobs

    if ($perfmonMin)
    {
        add-job -jobName "perfmon" -scriptBlock {
            param($workdir = $args[0], $perfmonMin = $args[1])
            $Counters = @(
                "\\$($env:computername)\processor(_total)\*",
                "\\$($env:computername)\memory\available mbytes",
                "\\$($env:computername)\memory\pool paged bytes",
                "\\$($env:computername)\memory\pool nonpaged bytes",
                "\\$($env:computername)\network adapter(*)\packets/sec",
                "\\$($env:computername)\network adapter(*)\current bandwidth",
                "\\$($env:computername)\physicaldisk(*)\% idle time",
                "\\$($env:computername)\physicaldisk(*)\current disk queue length",
                "\\$($env:computername)\process(*)\% processor time"
            )
            
            $logStream = new-object System.IO.StreamWriter ("$($workdir)\PerfmonCounters.csv, $true)
            $logStream.WriteLine("timestamp,path,value")
            $iterations = ($perfmonMin * 60)
            
            try
            {
                for ($count = 0; $count -le $iterations; $count++)
                {
                    foreach ($counter in (Get-Counter -Counter $Counters -MaxSamples 1 -erroraction silentlycontinue))
                    {
                        foreach($sample in $counter.CounterSamples)
                        {           
                            $logStream.WriteLine("$($sample.TimeStamp),$($sample.Path),$($sample.CookedValue)")
                        }
                    } 
                }
            }
            finally
            {
                $logstream.close()
                $logstream = $Null
            }
        } -arguments @($workdir,$perfmonMin)
    }

    if ($netmonMin)
    {
        add-job -jobName "netmon" -scriptBlock {
            param($workdir = $args[0], $netmonMin = $args[1])
            $timer = get-date
            Invoke-Expression "netsh trace start capture=yes overwrite=yes maxsize=1024 tracefile=$($workdir)\net.etl filemode=circular > $($workdir)\netmon.txt"
            while(((get-date) - $timer).TotalMinutes -lt $netmonMin)
            {
                start-sleep -seconds 1
            }
            Invoke-Expression "netsh trace stop >> $($workdir)\netmon.txt"
        } -arguments @($workdir,$netmonMin)
    }

    if ($runCommand)
    {
        add-job -jobName "runCommand" -scriptBlock {
            param($workdir = $args[0], $runCommand = $args[1])
            Invoke-Expression "$($runCommand) > $($workdir)\runCommand.txt"
        } -arguments @($workdir,$runCommand)
    }

    write-host "formatting xml files"
    foreach ($file in (get-childitem -filter *.xml -Path "$($workdir)" -Recurse))
    {
        # format xml in output
        read-xml -xmlFile $file.FullName -format
    }

    monitor-jobs

    $global:zipFile = compress-file $workDir
}

function add-job($jobName, $scriptBlock, $arguments)
{
    write-host "adding job $($jobName)"
    [void]$jobs.Add((Start-Job -Name $jobName -ScriptBlock $scriptBlock -ArgumentList $arguments))
}

function compress-file($dir)
{
    $zipFile = "$($dir).zip"
    write-host "creating zip $($zipFile)"
    write-debug "zip dir before: $(tree /a /f $dir | out-string)"

    if ((test-path $zipFile ))
    {
        remove-item $zipFile -Force
    }

    Stop-Transcript | out-null

    if (!$legacy)
    {
        Compress-archive -path $dir -destinationPath $zipFile -Force
    }
    else
    {
        Add-Type -Assembly System.IO.Compression.FileSystem
        $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
        [void][System.IO.Compression.ZipFile]::CreateFromDirectory($dir, $zipFile, $compressionLevel, $false)
    }

    Start-Transcript -Path $logFile -Force -Append | Out-Null
    $global:zipFile = $zipFile
    write-debug "zip dir after: $(tree /a /f $dir | out-string)"
    return $zipFile
}

function enumerate-serviceFabric()
{
    $fabricDataRoot = (get-itemproperty -path $serviceFabricInstallReg).fabricdataroot
    write-host "fabric data root:$($fabricDataRoot)"
    if (!$fabricDataRoot)
    {
        $fabricDataRoot = "d:\"
    }

    add-job -jobName "fabric config files" -scriptBlock {
        param($workdir = $args[0], $fabricDataRoot = $args[1])
        Get-ChildItem $($fabricDataRoot) -Recurse | out-file "$($workDir)\dir-fabricdataroot.txt"
        Copy-Item -Path $fabricDataRoot -Filter "*.xml" -Destination $workdir -Recurse
    } -arguments @($workdir, $fabricDataRoot)

    $clusterManifestFile = "$($fabricDataRoot)\clustermanifest.xml"
    if ((test-path $clusterManifestFile))
    {
        write-host "reading $($clusterManifestFile)"    
        $xml = read-xml -xmlFile $clusterManifestFile
        $xml.clustermanifest
        $seedNodes = $xml.ClusterManifest.Infrastructure.PaaS.Votes.Vote
        write-host "seed nodes: $($seedNodes | format-list * | out-string)"
        $nodeCount = $xml.ClusterManifest.Infrastructure.PaaS.Roles.Role.RoleNodeCount
        write-host "node count:$($nodeCount)"
        $clusterId = (($xml.ClusterManifest.FabricSettings.Section | Where-Object Name -eq "Paas").childnodes | where-object Name -eq "ClusterId").value
        write-host "cluster id:$($clusterId)"
        $upgradeServiceParams = ($xml.ClusterManifest.FabricSettings.Section | Where-Object Name -eq "UpgradeService").parameter
        $sfrpUrl = ($upgradeServiceParams | Where-Object Name -eq "BaseUrl").Value
        $sfrpUrl = "$($sfrpUrl)$($clusterId)"
        write-host "sfrp url:$($sfrpUrl)"
        out-file -InputObject $sfrpUrl "$($workdir)\sfrp-response.txt"
        $ucert = ($upgradeServiceParams | Where-Object Name -eq "X509FindValue").Value
        $sfrpResponse = Invoke-WebRequest $sfrpUrl -UseBasicParsing -Certificate (Get-ChildItem -Path Cert:\LocalMachine\My -Recurse | Where-Object Thumbprint -eq $ucert)
        write-host "sfrp response: $($sfrpresponse)"
        out-file -Append -InputObject $sfrpResponse "$($workdir)\sfrp-response.txt"


        $httpGwEpt = $xml.ClusterManifest.NodeTypes.FirstChild.Endpoints.HttpGatewayEndpoint
        $clusterCertThumb = $xml.ClusterManifest.NodeTypes.FirstChild.Certificates.ClientCertificate.X509FindValue
        $clusterCert = (Get-ChildItem -Path Cert:\LocalMachine\My -Recurse | Where-Object Thumbprint -eq $clusterCertThumb)
        write-host "cluster cert: $($clusterCert | format-list *)"
        
        # todo handle continuationtoken
        $gwEpt = "$($httpGwEpt.Protocol)://localhost:$($httpGwEpt.Port)"
        $urlArgs = "api-version=$($apiversion)&timeout=$($restTimeoutSec)&StartTimeUtc=$($startTime.ToString(`"yyyy-MM-ddTHH:mm:ssZ`"))&EndTimeUtc=$($endTime.ToString(`"yyyy-MM-ddTHH:mm:ssZ`"))"

        rest-query -url "$($gwEpt)/ImageStore?$($urlArgs)" -cert $clusterCert | out-file "$($workdir)\rest-imageStore.txt" 
        rest-query -url "$($gwEpt)/Nodes?$($urlArgs)" -cert $clusterCert | out-file "$($workdir)\rest-nodes.txt"
        rest-query -url "$($gwEpt)/$/GetClusterHealth?$($urlArgs)" -cert $clusterCert | out-file "$($workdir)\rest-getClusterHealth.txt"
        rest-query -url "$($gwEpt)/EventsStore/Cluster/Events?$($urlArgs)" -cert $clusterCert | out-file "$($workdir)\rest-eventsCluster.txt"
        rest-query -url "$($gwEpt)/EventsStore/Nodes/Events?$($urlArgs)" -cert $clusterCert | out-file "$($workdir)\rest-eventsNodes.txt"
        rest-query -url "$($gwEpt)/EventsStore/Applications/Events?$($urlArgs)" -cert $clusterCert | out-file "$($workdir)\rest-eventsApplications.txt"
        rest-query -url "$($gwEpt)/EventsStore/Services/Events?$($urlArgs)" -cert $clusterCert | out-file "$($workdir)\rest-eventsServices.txt"
        rest-query -url "$($gwEpt)/EventsStore/Partitions/Events?$($urlArgs)" -cert $clusterCert | out-file "$($workdir)\rest-eventsPartition.txt"
    }

    $fabricRoot = (get-itemproperty -path $serviceFabricInstallReg).fabricroot
    write-host "fabric root:$($fabricRoot)"
    Get-ChildItem $($fabricRoot) -Recurse | out-file "$($workDir)\dir-fabricroot.txt"
}

function monitor-jobs()
{
    $incompletedCount = 0

    while (@(get-job).Count -gt 0)
    {
        $incompleteCount = @(get-job | Where-Object State -eq "Running").Count
        
        if ($incompleteCount -eq 0 -or $incompletedCount -ne $incompleteCount)
        {
            write-host "`n$((get-date).ToString("HH:mm:sszz")) waiting on $($incompleteCount) jobs..." -ForegroundColor Yellow
            $incompletedCount = $incompleteCount
            
            foreach ($job in get-job)
            {
                write-host ("name:$($job.Name) state:$($job.State) output:$((Receive-Job -job $job | format-list * | out-string))") -ForegroundColor Cyan
    
                if ($job.State -imatch "Failed|Completed")
                {
                    remove-job $job -Force
                }
            }

            continue
        }

        start-sleep -seconds 1
        write-host "." -NoNewline

        if (((get-date) - $timer).TotalMinutes -ge $timeoutMinutes)
        {
            write-error "script timed out waiting for jobs to complete totalMinutes: $($timeoutMinutes) minutes"
            get-job | receive-job
            get-job | remove-job -force
            return
        }
    }
}

function read-xml($xmlFile, [switch]$format)
{
    try
    {
        write-host "reading xml file $($xmlFile)"
        [Xml.XmlDocument] $xdoc = New-Object System.Xml.XmlDocument
        [void]$xdoc.Load($xmlFile)

        if ($format)
        {
            [IO.StringWriter] $sw = new-object IO.StringWriter
            [Xml.XmlTextWriter] $xmlTextWriter = new-object Xml.XmlTextWriter ($sw)
            $xmlTextWriter.Formatting = [Xml.Formatting]::Indented
            $xdoc.PreserveWhitespace = $true
            [void]$xdoc.WriteTo($xmlTextWriter)
            #write-host ($sw.ToString())
            out-file -FilePath $xmlFile -InputObject $sw.ToString()
        }

        return $xdoc
    }
    catch
    {
        return $Null
    }
}

function rest-query($cert, $url)
{
    try
    {
        $result = $null
        write-host "rest query: $($url)" -foregroundcolor cyan
        $result = Invoke-RestMethod -Method Get -Certificate $cert -Uri $url -UseBasicParsing | format-list * | Out-String
        write-host "rest result: `n$($result)"
        return $result
    }
    catch
    {
        return $Null
    }
}

try
{
    main
}
catch
{
    write-error "main exception: $($error | out-string)"
}
finally
{
    if ($winrmClientInfo)
    {
        # set local machine back
        winrm set winrm/config/client "@{TrustedHosts="$($trustedHosts)"}"
    }

    if ($disableWarnOnZoneCrossing)
    {
        New-ItemProperty -Path $warnonZoneCrossingReg -Name "WarnonZoneCrossing" -Value 0 -PropertyType DWORD -Force | Out-Null
    }

    set-location $currentWorkDir
    get-job | remove-job -Force
    write-host "finished. total minutes: $(((get-date) - $timer).TotalMinutes.tostring("F2"))"
    write-debug "errors during script: $($error | out-string)"
    Stop-Transcript
    write-host "upload zip to workspace:$($global:zipFile)" -ForegroundColor Cyan
}
