#Requires -Version 3.0
Param(
    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string] $ClusterDataRootPath="D:\SvcFab",

    [Parameter(Mandatory=$false)] 
    [ValidateNotNullOrEmpty()]
    [string]$NodeToFake="_sys_4",

    [Parameter(Mandatory=$false)] #$true
    [ValidateNotNullOrEmpty()]
    [string]$TemporaryNodeIpAddress="10.0.0.10" # ip address for this node which we will fake into looking like $NodeToFake - missing seed node _sys_4
)

Set-StrictMode -Version 3

$ErrorActionPreference = "Stop"

If(!(Test-Path $ClusterDataRootPath))
{
    Write-Host $ClusterDataRootPath " not found, exiting."
    Exit-PSSession
}

function StopServiceFabricServices
{
        $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
        $fabricHost = "FabricHostSvc"

        $bootstrapService = Get-Service -Name $bootstrapAgent
        if ($bootstrapService.Status -eq "Running"){
            Stop-Service $bootstrapAgent
            Write-Host "Stopping " $bootstrapAgent " service" 
        } else { Write-Host $fabricHost " not Running" }
        Do
        {
            Start-Sleep -Seconds 1
            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Stopped"){
                Write-Host $bootstrapAgent " now stopped" 
            } else {
                Write-Host $bootstrapAgent " current status:" $bootstrapService.Status
            }

        } While ($bootstrapService.Status -ne "Stopped")

        $fabricHostService = Get-Service -Name $fabricHost
        if ($fabricHostService.Status -eq "Running"){
            Stop-Service $fabricHost
            Write-Host "Stopping " $fabricHost " service" 
        } else { Write-Host $fabricHost " not Running" }
        Do
        {
            Start-Sleep -Seconds 1
            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Stopped"){            
                Write-Host $fabricHost " now stopped" 
            } else {
                Write-Host $fabricHost " current status:" $fabricHostService.Status
            }

        } While ($fabricHostService.Status -ne "Stopped")
    }

function StartServiceFabricServices
{
        $bootstrapAgent = "ServiceFabricNodeBootstrapAgent"
        $fabricHost = "FabricHostSvc"

        $fabricHostService = Get-Service -Name $fabricHost
        if ($fabricHostService.Status -eq "Stopped"){
            Start-Service $fabricHost -ErrorAction SilentlyContinue -ErrorVariable FabricHostProcessError
            Write-Host "Starting" $fabricHost " service" 
        } else { Write-Host $fabricHost " not Stopped" }
        Do
        {
            Start-Sleep -Seconds 1
            $fabricHostService = Get-Service -Name $fabricHost
            if ($fabricHostService.Status -eq "Running"){
                Write-Host $fabricHost " now running" 
            } else {
                Write-Host $fabricHost " current status:" $fabricHostService.Status
            }

        } While ($fabricHostService.Status -ne "Running")


        $bootstrapService = Get-Service -Name $bootstrapAgent
        if ($bootstrapService.Status -eq "Stopped"){
            Start-Service $bootstrapAgent  -ErrorAction SilentlyContinue -ErrorVariable BootstrapProcessError
            Write-Host "Starting" $bootstrapAgent " service" 
        } else { Write-Host $bootstrapAgent " not Stopped" }
        Do
        {
            Start-Sleep -Seconds 1
            $bootstrapService = Get-Service -Name $bootstrapAgent
            if ($bootstrapService.Status -eq "Running"){            
                Write-Host $bootstrapAgent " now running" 
            } else {
                Write-Host $bootstrapAgent " current status:" $bootstrapService.Status
            }

        } While ($bootstrapService.Status -ne "Running")
    }


# Stop the Service Fabric services
Write-Host "Stopping services "
StopServiceFabricServices

# Parse and locate important configuration files
$result = Get-ChildItem -Path $ClusterDataRootPath -Filter "Fabric.Data" -Directory -Recurse
$hostPath = $result.Parent.Parent.Name 
Write-Host "---------------------------------------------------------------------------------------------------------"
Write-Host "---- Working on ip:" $hostPath
Write-Host "---------------------------------------------------------------------------------------------------------"

$manifestPath = $ClusterDataRootPath + "\" + $hostPath + "\Fabric\ClusterManifest.current.xml"
$currentPackage = $ClusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Package.current.xml"
$infrastructureManifest = $ClusterDataRootPath + "\" + $hostPath + "\Fabric\Fabric.Data\InfrastructureManifest.xml"

# Create the temp folder
$tempFolder = 'd:\temp\seednodework'
New-Item -ItemType Directory -Force -Path $tempFolder

# Read and update current configs, save to the temp folder with new names
$newManifest = Join-Path $tempFolder 'modified_clustermanifest.xml'
$newInfraManifest = Join-Path $tempFolder 'modified_InfrastructureManifest.xml'

# Parse seednodes
$clusterManifest = [xml](Get-Content $manifestPath)
$seednodes = $clusterManifest.ClusterManifest.Infrastructure.PaaS.Votes.Vote

$oldIp = '0.0.0.0'
foreach($vote in $seednodes)
{
    Echo $vote.NodeName
    if($vote.NodeName -eq $NodeToFake)
    {
        $oldIp = $vote.IPAddressOrFQDN
        break
    }
}

if($oldIp -eq '0.0.0.0')
{
    Write-Host 
    Write-Host "Error: Cannot find Vote entry for " $($NodeToFake) " in " $($manifestPath)
    Write-Host 

    Stop
}

# Find and replace old ip with the new one
(Get-Content $manifestPath |
    Foreach-Object { $_ -replace $oldIp, $TemporaryNodeIpAddress } |
    Set-Content $newManifest)

# Find and replace old ip with the new one, and current nodename with nodetofake
(Get-Content $infrastructureManifest |
    Foreach-Object { $_ -replace $oldIp, $TemporaryNodeIpAddress } |
    Foreach-Object { $_ -replace $hostPath, $NodeToFake } |
    Set-Content $newInfraManifest)

# Create new node configuration
New-ServiceFabricNodeConfiguration -ClusterManifestPath $newManifest -InfrastructureManifestPath $newInfraManifest

# Rename the old node configuration folder
$fullHostPath = Join-Path $ClusterDataRootPath $hostPath
$oldHostPath = Join-Path $tempFolder "oldNode"
New-Item -ItemType Directory -Force -Path $oldHostPath
Get-ChildItem -Path $fullHostPath -Recurse |
  Move-Item -destination $oldHostPath
Remove-Item $fullHostPath -Force

# Restart the Service Fabric services
Write-Host "Starting services "
StartServiceFabricServices
