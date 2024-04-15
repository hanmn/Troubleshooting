<#
.SYNOPSIS
# script to schedule task
# schedule-task.ps1
# writes event 4103 to Microsoft-Windows-Powershell on completion in Operational event log

.LINK
    invoke-webRequest "https://raw.githubusercontent.com/Azure/Service-Fabric-Troubleshooting-Guides/master/scripts/schedule-task.ps1" -outFile "$pwd\schedule-task.ps1";

.EXAMPLE 
    download script file task.ps1, schedule task at startup and execute task immediately.
    .\schedule-task.ps1 -start -scriptFile https://raw.githubusercontent.com/{{owner}}/{{repo}}/master/temp/task.ps1

.EXAMPLE 
    download script file task.ps1, schedule task for weekly execute on sunday at 3am and task immediately.
    .\schedule-task.ps1 -triggerFrequency weekly -start -scriptFile https://raw.githubusercontent.com/{{owner}}/{{repo}}/master/temp/task.ps1

.EXAMPLE 
    schedule task for daily execute of inline powerhsell command get-winevent.
    .\schedule-task.ps1 -triggerFrequency daily -action powershell -actionParameter '-Command {get-winevent -LogName Application | ? LevelDisplayName -notmatch 'information'}'

.PARAMETER scriptFileStoragePath
    [string] storage location for script file on machine referenced by scheduled task.

.PARAMETER scriptFile
    [string] optional script file to be used in scheduled task. can be drive letter, unc, or url. 
    $scriptFile will be downloaded to $scriptFileStoragePath.
    schedule-task.ps1 script $action and $actionParameter are by default confitured to run powershell scripts.
    $scriptFile if provided will be appended to $actionParameter in format $scriptFileStoragePath\$scriptFile.

.PARAMETER taskName
    [string] name of scheduled task.

.PARAMETER action
    [string] action for scheduled task to perform.

.PARAMETER actionParameter
    [string] action parameter(s) for $action.
    $scriptFile if provided will be appended to $actionParameter in format $scriptFileStoragePath\$scriptFile.

.PARAMETER triggerTime
    [datetime]/[string] time to start trigger execution. 
    see https://docs.microsoft.com/powershell/module/scheduledtasks/new-scheduledtasktrigger

.PARAMETER triggerFrequency
    [string] scheduled task trigger frequency, one of: 'startup', 'once', 'daily', 'weekly'

.PARAMETER principal
    [string] scheduled task authentication principal

.PARAMETER principalLogonType
    [string] principal logon type. 
    one of: 'none', 'password', 's4u', 'interactive', 'serviceaccount', 'interactiveorpassword', 'group'

.PARAMETER start
    [switch] start scheduled task

.PARAMETER runLevel
    [string] scheduled task execution level. 
    one of: 'highest', 'limited'

.PARAMETER daysOfWeek
    [string[]] days of week if $triggerFrequency equals 'weekly'.
    one or more of: 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'

.PARAMETER daysInterval
    [int] time interval in days between scheduled task if $triggerFrequency equals 'daily'.

.PARAMETER remove
    [switch] remove existing scheduled task and returns.

.PARAMETER taskSettingsParameters
    [hashtable] optional additional task settings paramaters to be passed to new-taskschedulesettingsset command.
    example: .\schedule-task.ps1 -triggerFrequency weekly -taskSettingsParameters @{restartCount=3;runOnlyIfNetworkAvailable=$true}
    see https://docs.microsoft.com/powershell/module/scheduledtasks/new-scheduledtasksettingsset.

#>

param(
    [string]$scriptFileStoragePath = 'c:\task-scripts', #$pwd, #$PSScriptRoot,
    [string]$scriptFile = '',
    [string]$taskName = 'az-vmss-cse-task',
    [string]$action = 'powershell.exe',
    [string]$actionParameter = '-ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoLogo -NoProfile',
    [string]$triggerTime = '3am',
    [ValidateSet('startup', 'once', 'daily', 'weekly')]
    [string]$triggerFrequency = 'startup',
    [string]$principal = 'BUILTIN\ADMINISTRATORS', #'SYSTEM',
    [ValidateSet('none', 'password', 's4u', 'interactive', 'serviceaccount', 'interactiveorpassword', 'group')]
    [string]$principalLogonType = 'group',
    [switch]$start,
    [ValidateSet('highest', 'limited')]
    [string]$runLevel = 'limited',
    [ValidateSet('sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday')]
    [string[]]$daysOfweek = @('sunday'),
    [int]$daysInterval = 1,
    [switch]$remove,
    [hashtable]$taskSettingsParameters = @{}
)

$PSModuleAutoLoadingPreference = 2
$ErrorActionPreference = $VerbosePreference = $DebugPreference = 'continue'
$transcriptlog = "$PSScriptRoot\transcript.log"
Start-Transcript -Path $transcriptlog
$global:currentTask = $null

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (!$isAdmin) {
    write-error "not administrator"
}

write-output (whoami /user)
write-output (whoami /groups)

$global:currentTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($global:currentTask) {
    write-output "deleting current task $taskname"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

if ($remove) {
    write-output 'remove finished'
    Stop-Transcript
    return $error.Count
}

$error.clear()

if ($scriptFile) {
    if (!(Test-Path $scriptFileStoragePath -PathType Container)) { 
        mkdir $scriptFileStoragePath
    }
    
    $scriptFileName = [io.path]::GetFileName($scriptFile)

    if ($scriptFile.StartsWith('http')) {
        Invoke-WebRequest -Uri $scriptFile -OutFile "$($scriptFileStoragePath)\$($scriptFileName)" -UseBasicParsing
    }
    else {
        copy-item $scriptFile -Destination $scriptFileStoragePath
    }

    $scriptFile = "$($scriptFileStoragePath)\$($scriptFileName)"
    write-output "script file: $scriptFile"

    if (!(test-path $scriptFile)) {
        write-error "$scriptFile does not exist"
        Stop-Transcript
        throw [ArgumentException]::new("$scriptFile does not exist")
    }

    $scriptFile = " -File `"$($scriptFileStoragePath)\$($scriptFileName)`""
}

write-output "`$taskAction = New-ScheduledTaskAction -execute $action -argument $actionParameter$scriptFile"
$taskAction = New-ScheduledTaskAction -execute $action -argument "$actionParameter$scriptFile"

$taskTrigger = $null

switch ($triggerFrequency) {
    "startup" { 
        write-output "`$taskTrigger = New-ScheduledTaskTrigger -AtStartup"
        $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    }
    "once" { 
        write-output "`$taskTrigger = New-ScheduledTaskTrigger -once -At $triggerTime"
        $taskTrigger = New-ScheduledTaskTrigger -once -At $triggerTime
    }
    "daily" { 
        write-output "`$taskTrigger = New-ScheduledTaskTrigger -daily -At $triggerTime -DaysInterval $daysInterval"
        $taskTrigger = New-ScheduledTaskTrigger -daily -At $triggerTime -DaysInterval $daysInterval
    }
    "weekly" { 
        write-output "`$taskTrigger = New-ScheduledTaskTrigger -weekly -At $triggerTime -DaysOfWeek $daysOfweek"
        $taskTrigger = New-ScheduledTaskTrigger -weekly -At $triggerTime -DaysOfWeek $daysOfweek
    }
}

write-output "trigger:`r`n$($taskTrigger | convertto-json -depth 1)"

$taskPrincipal = $null

if ($principalLogonType -ieq 'group') {
    write-output "`$taskPrincipal = New-ScheduledTaskPrincipal -GroupId $principal -RunLevel $runLevel"
    $taskPrincipal = New-ScheduledTaskPrincipal -GroupId $principal -RunLevel $runLevel
}
else {
    write-output "`$taskPrincipal = New-ScheduledTaskPrincipal -UserId $principal -LogonType $principalLogonType -RunLevel $runLevel"
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId $principal -LogonType $principalLogonType -RunLevel $runLevel
}

write-output "principal:`r`n$($taskPrincipal | convertto-json -depth 1)"

Write-Output "`$settings = New-ScheduledTaskSettingsSet $taskSettingsParameters"
$settings = New-ScheduledTaskSettingsSet @taskSettingsParameters
write-output "settings:`r`n$($settings | convertto-json -depth 1)"

write-output "`$result = Register-ScheduledTask -TaskName $taskName `
    -Action $taskAction `
    -Trigger $taskTrigger `
    -Settings $settings `
    -Principal $taskPrincipal `
    -Force
"

$result = Register-ScheduledTask -TaskName $taskName `
    -Action $taskAction `
    -Trigger $taskTrigger `
    -Settings $settings `
    -Principal $taskPrincipal `
    -Force

write-output ($result | convertto-json)
write-output ($MyInvocation | convertto-json)

$global:currentTask = Get-ScheduledTask -TaskName $taskName
write-output ($global:currentTask | convertto-json)

if ($start) {
    $startResults = Start-ScheduledTask -TaskName $taskName
}

write-output ($startResults | convertto-json)

$success = $global:currentTask -ne $null
$context = "context:`r`nsuccess:$success`r`nfailures:$($error.count)`r`nlog:file://$transcriptLog`r`n$(($MyInvocation | convertto-json -Depth 1))"
$userData = "user data:`r`n$(([environment]::GetEnvironmentVariables() | convertto-json))"
$startResults = "start results:`r`n$(($startResults | convertto-json -Depth 1))
    current task:`r`n$(($global:currentTask | convertto-json -Depth 1))
    error:`r`n$(($error | convertto-json -Depth 1))"

New-WinEvent -ProviderName Microsoft-Windows-Powershell `
    -id 4103 `
    -Payload @($context, $userData, $startResults)

write-output "finished. returning:$result log location: $transcriptLog"

Stop-Transcript
if(!$success) {
    throw [exception]::new("task not created $taskName")
}
return $error.Count