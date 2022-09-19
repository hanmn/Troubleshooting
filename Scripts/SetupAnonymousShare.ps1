#
# Example configuring a Standalone cluster Diagnostics Share on non-domain joined nodes \\node1\DiagnosticsStore
#
# "diagnosticsStore": 
# {
#    "metadata":  "Please replace the diagnostics file share with an actual file share accessible from all cluster machines. For example, \\\\machine1\\DiagnosticsStore.",
#    "dataDeletionAgeInDays": "21",
#    "storeType": "FileShare",
#    "connectionstring": "\\\\node1\\DiagnosticsStore"
# },
#
# Instructions: 
# 1. Execute this script on node1 to create and configure the share
# 2. Update cluster configuration (this step is required even if the connection string configured already)
#    a. edit ClusterConfig.X509.MultiMachine.json and increment the config version, e.g. "clusterConfigurationVersion": "1.0.1",
#    b. start a configuration upgrade:  Start-ServiceFabricClusterConfigurationUpgrade -ClusterConfigPath .\ClusterConfig.X509.MultiMachine.json
#

# enable Guest account
net user guest /active:yes

# Create our Shared Folder and Share Name
$FolderPath = "c:\DiagnosticsShare"
$ShareName = "DiagnosticsStore"

If (!(TEST-PATH $FolderPath)) {  
            New-Item -type directory -Path $FolderPath 
} 

# Configure ACL's to allow all anonymous users to have full control of the Share path
$DiagShareAcl = Get-Acl -Path $FolderPath

$colRightsEveryone = [System.Security.AccessControl.FileSystemRights]"FullControl" 
$permissionEveryone = "Everyone",$colRightsEveryone,"ContainerInherit,ObjectInherit","None","Allow" 
$accessRuleEveryone = New-Object System.Security.AccessControl.FileSystemAccessRule $permissionEveryone 
$DiagShareAcl.AddAccessRule($accessRuleEveryone) 

$colRightsEveryone = [System.Security.AccessControl.FileSystemRights]"FullControl" 
$permissionEveryone = "ANONYMOUS LOGON",$colRightsEveryone,"ContainerInherit,ObjectInherit","None","Allow" 
$accessRuleEveryone = New-Object System.Security.AccessControl.FileSystemAccessRule $permissionEveryone 
$DiagShareAcl.AddAccessRule($accessRuleEveryone) 

$colRightsEveryone = [System.Security.AccessControl.FileSystemRights]"FullControl" 
$permissionEveryone = "Guest",$colRightsEveryone,"ContainerInherit,ObjectInherit","None","Allow" 
$accessRuleEveryone = New-Object System.Security.AccessControl.FileSystemAccessRule $permissionEveryone 
$DiagShareAcl.AddAccessRule($accessRuleEveryone) 

$DiagShareAcl | Set-Acl $FolderPath 

# Share the folder with these specific users
net share $ShareName=$FolderPath /grant:Administrators`,FULL /grant:Everyone`,FULL /grant:"Anonymous Logon"`,FULL /grant:Guest`,FULL

# update local policy to enable anonymous access
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\LSA -Name EveryoneIncludesAnonymous -Value 1
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters -Name RestrictNullSessAccess -Value 0
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters -Name NullSessionShares -Value $ShareName
