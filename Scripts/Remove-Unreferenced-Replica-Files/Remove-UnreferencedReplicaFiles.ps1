<#
    .SYNOPSIS
        Removes files corresponding to leaked replicas.

    .DESCRIPTION
        When a replica is force removed, files associated with it are not removed from the file system. This tool deletes those files.

    .EXAMPLE
        Deletes all leaked files.
        .\Remove-UnreferencedReplicaFiles.ps1 -NodeName <NodeName>

        Shows what would happen if the cmdlet runs.
        .\Remove-UnreferencedReplicaFiles.ps1 -NodeName <NodeName> -WhatIf

        Deletes and displays leaked files corresponding to force removed replicas.
        .\Remove-UnreferencedReplicaFiles.ps1 -NodeName <NodeName> -Verbose
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true)]
    [string]
    $NodeName,

    [Parameter(Mandatory=$false)]
    [switch]
    $WhatIf=$false
)

function GetApplicationDeployedNode
{
    <#
        .SYNOPSIS 
        Returns a node on which the given application is deployed.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Fabric.Query.Application]
        $Application
    )

    $services = Get-ServiceFabricService -ApplicationName $Application.ApplicationName
    foreach ($service in $services)
    {
        if ($service.ServiceKind.ToString() -eq "Stateful")
        {
            $partitions = Get-ServiceFabricPartition -ServiceName $service.ServiceName
            foreach ($partition in $partitions)
            {
                $replicas = Get-ServiceFabricReplica -PartitionId $partition.PartitionId
                foreach ($replica in $replicas)
                {
                    $nameOfNode = $replica.NodeName
                    return $nameOfNode
                }
            }
        }
    }
    
    return $null
}

function GetWorkDirectories
{
    <#
        .SYNOPSIS 
        Returns work directories. If the application is not deployed on the given node, it gets work directory path from 
        another node on which this application is deployed.
        Assumed that the work directories will be the same (all the nodes the application runs on have the same 
        configuration), and this script fails to cleanup the leaked files if the work directories are different.
    #>

    $workDirectories = New-Object System.Collections.ArrayList

    $applicationsInCluster = Get-ServiceFabricApplication
    foreach ($application in $applicationsInCluster)
    {
        $deployedApplication = Get-ServiceFabricDeployedApplication -NodeName $NodeName -ApplicationName $application.ApplicationName
 
        if ($null -eq $deployedApplication)
        {
            $nameOfNode = GetApplicationDeployedNode -Application $application

            if ($null -eq $nameOfNode)
            {
                continue
            }

            $deployedApplication = Get-ServiceFabricDeployedApplication -NodeName $nameOfNode -ApplicationName $application.ApplicationName
        }

        $workDirectory = $deployedApplication.WorkDirectory
        [void] $workDirectories.Add($workDirectory)
    }

    return $workDirectories
}

function GetWorkDirectoriesContent
{
    <#
        .SYNOPSIS 
        Returns content of work directories.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Collections.ArrayList]
        [AllowEmptyCollection()]
        $WorkDirectories
    )

    $content = New-Object System.Collections.ArrayList

    foreach ($workDirectory in $WorkDirectories)
    {
        if (Test-Path $workDirectory)
        {
            $paths = Get-Childitem -Path $workDirectory

            $content.AddRange($paths);
        }
    }

    return $content
}

function GetActivePartitions
{
    <#
        .SYNOPSIS 
        Returns all active partitions.
    #>

    $partitionDescriptionMap = @{}

    $deployedApplications = Get-ServiceFabricDeployedApplication -NodeName $NodeName
    foreach ($application in $deployedApplications)
    {
        $applicationName = $application.ApplicationName

        $services = Get-ServiceFabricService -ApplicationName $applicationName
        foreach ($service in $services)
        {
            if ($service.ServiceKind.ToString() -eq "Stateful")
            {
                $serviceName = $service.ServiceName

                $partitions = Get-ServiceFabricPartition -ServiceName $serviceName
                foreach ($partition in $partitions)
                {
                    $partitionId = $partition.PartitionId

                    $applicationNameAndServiceName = $applicationName.ToString(), $serviceName.ToString()
                    [void] $partitionDescriptionMap.Add($partitionId, $applicationNameAndServiceName)
                }
            }
        }
    }

    return $partitionDescriptionMap
}

function HasCheckpointFiles
{
    <#
        .SYNOPSIS 
        Given a directory, checks if it contains checkpoint files.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $Directory,

        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.HashSet[string]]
        [AllowEmptyCollection()]
        $CheckpointExtensions
    )

    $paths = Get-ChildItem -Path $Directory

    foreach ($path in $paths)
    {
        if ((-not ((Get-Item $path.FullName) -is [System.IO.DirectoryInfo])) -and $CheckpointExtensions.Contains($path.Extension))
        {
            return $true
        }
    }

    return $false
}

function AddPartitionReplicaIdEntryToMap
{
    <#
        .SYNOPSIS 
        Given a map, adds a partitionid_replicaid entry to the map if it does not exist.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $PartitionReplicaIds,

        [Parameter(Mandatory=$true)]
        [System.Collections.Hashtable]
        [AllowEmptyCollection()]
        $ReplicaToFilesMap
    )

    if (-not $ReplicaToFilesMap.ContainsKey($PartitionReplicaIds))
    {
        $files = New-Object System.Collections.ArrayList
        [void] $ReplicaToFilesMap.Add($PartitionReplicaIds, $files)
    }
}

function GetForceRemovedReplicaToFilesMap
{
    <#
        .SYNOPSIS 
        Returns all force removed replicas and leaked files corresponding to those replicas.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.HashSet[string]]
        [AllowEmptyCollection()]
        $PartitonReplicaIdsSet,

        [Parameter(Mandatory=$true)]
        [System.Collections.ArrayList]
        [AllowEmptyCollection()]
        $WorkDirectoriesContent,

        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.HashSet[string]]
        [AllowEmptyCollection()]
        $CheckpointFileExtensions
    )

    $deletedReplicaToFilesMap = @{}

    # Go through paths in work directories and add leaked files to the map
    foreach ($path in $WorkDirectoriesContent)
    {
        $fileName = Split-Path $path.FullName -leaf
        $ids = $fileName.split('_')
        if (($ids.Count -gt 1) -and ($ids[0].Length -eq 32) -and ($ids[1].Length -eq 18))
        {
            $partitionReplicaIds = $ids[0] + "_" + $ids[1]

            if ($PartitonReplicaIdsSet.Contains($partitionReplicaIds) -eq $false)
            {
                # Add the directory path if it either does not contain any files or if it contains checkpoint files, 
                # but not if it contains only some random files
                if ((Get-Item $path.FullName) -is [System.IO.DirectoryInfo])
                {
                    $containsCheckpointFiles = HasCheckpointFiles -Directory $path.FullName -CheckpointExtensions $CheckpointFileExtensions
                    if (((Get-ChildItem $path.FullName | Measure-Object).Count -eq 0) -or $containsCheckpointFiles)
                    {
                        AddPartitionReplicaIdEntryToMap -PartitionReplicaIds $partitionReplicaIds -ReplicaToFilesMap $deletedReplicaToFilesMap

                        [void] $deletedReplicaToFilesMap[$partitionReplicaIds].Add($path.FullName)
                        continue;
                    }
                }
                else
                {
                    AddPartitionReplicaIdEntryToMap -PartitionReplicaIds $partitionReplicaIds -ReplicaToFilesMap $deletedReplicaToFilesMap

                    # Delete both log reference and log files
                    if ([IO.Path]::GetExtension($path.FullName) -eq '.SFlogref')
                    {
                        $logFilePath = Get-Content -Path $path.FullName
                        if (Test-Path $logFilePath)
                        {
                            [void] $deletedReplicaToFilesMap[$partitionReplicaIds].Add($logFilePath)
                        }
                    }

                    [void] $deletedReplicaToFilesMap[$partitionReplicaIds].Add($path.FullName)
                }
            }
        }
        
    }

    return $deletedReplicaToFilesMap
}

function GetReplicaDescription
{
    <#
        .SYNOPSIS 
        Given a string in partitionid_replicaid format, returns replica info which includes application name, 
        service name, partition id and replica id.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $PartitionReplicaIds,

        [Parameter(Mandatory=$true)]
        [System.Collections.Hashtable]
        [AllowEmptyCollection()]
        $PartitionDescriptionMap
    )

    [GUID]$partitionId = $PartitionReplicaIds.split('_')[0]
    $replicaId = $PartitionReplicaIds.split('_')[1]
    if ($PartitionDescriptionMap.ContainsKey($partitionId))
    {
        $applicationName = ($PartitionDescriptionMap[$partitionId])[0]
        $serviceName = ($PartitionDescriptionMap[$partitionId])[1]

    }
    else
    {
        $applicationName = "Unknown"
        $serviceName = "Unknown"
    }

    $replicaDescription = "Application Name: ""{0}"" Service Name: ""{1}"" Partition ID: ""{2}"" Replica ID: ""{3}""" -f `
                            $applicationName, $serviceName, $partitionId, $replicaId

    return $replicaDescription
}

function PrintLeakedFilesInDirectory
{
    <#
        .SYNOPSIS 
        Prints what would be deleted from the directory.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $Directory,

        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.HashSet[string]]
        [AllowEmptyCollection()]
        $CheckpointExtensions
    )

    $paths = Get-Childitem -Path $Directory
    foreach ($path in $paths)
    {
        if (-not ((Get-Item $path.FullName) -is [System.IO.DirectoryInfo]) -and $CheckpointExtensions.Contains($path.Extension))
        {
            $fileRemovedInfo = "Removes {0}" -f $path.FullName
            Write-Verbose $fileRemovedInfo
        }
    }   
}

function PrintLeakedContent
{
    <#
        .SYNOPSIS 
        Prints what would be deleted if the cmdlet runs.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [System.Collections.Hashtable]
        [AllowEmptyCollection()]
        $ForceRemovedReplicasToFilesMap,

        [Parameter(Mandatory=$true)]
        [System.Collections.Hashtable]
        [AllowEmptyCollection()]
        $PartitionDescriptions,

        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.HashSet[string]]
        [AllowEmptyCollection()]
        $CheckpointFileExtensions
    )

    if ($ForceRemovedReplicasToFilesMap.Count -gt 0)
    {
        Write-Output "Removes files and folders corresponding to:"

        foreach ($partitionReplicaIds in $ForceRemovedReplicasToFilesMap.Keys)
        {
            $replicaRemovedInfo = GetReplicaDescription -PartitionReplicaIds $partitionReplicaIds -PartitionDescriptionMap $PartitionDescriptions

            Write-Output $replicaRemovedInfo

            # If Verbose flag is provided, show all leaked files
            $paths = $ForceRemovedReplicasToFilesMap[$partitionReplicaIds]
            foreach ($path in $paths)
            {
                if ((Get-Item $path) -is [System.IO.DirectoryInfo])
                {
                    PrintLeakedFilesInDirectory -Directory $path -CheckpointExtensions $CheckpointFileExtensions
                }
                else
                {
                    $fileRemovedInfo = "Removes {0}" -f $path
                    Write-Verbose $fileRemovedInfo
                }
            }
        }
    }
    else
    {
        Write-Output "There are no leaked files to remove."
    }
}

function RemoveCheckpointFilesFromDirectory
{
    <#
        .SYNOPSIS 
        Given a directory, deletes checkpoint files.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $CheckpointFilesDirectory,

        [Parameter(Mandatory=$true)]
        [System.Collections.Generic.HashSet[string]]
        [AllowEmptyCollection()]
        $CheckpointFileExtensions
    )

    $directoryContents = Get-Childitem -Path $CheckpointFilesDirectory
    foreach ($content in $directoryContents)
    {
        if (-not ((Get-Item $content.FullName) -is [System.IO.DirectoryInfo]) -and $CheckpointFileExtensions.Contains($content.Extension))
        {
            $fileRemovedInfo = "Removing {0}" -f $content.FullName
            Write-Verbose $fileRemovedInfo

            Remove-Item $content.FullName
        }
    }
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************

$_workDirectories = GetWorkDirectories

$_workDirectoriesContent = GetWorkDirectoriesContent -WorkDirectories $_workDirectories

# Map between active partitions and application name, service name
$_activePartitions = GetActivePartitions

$_activeReplicas = New-Object System.Collections.Generic.HashSet[string]
foreach ($partitionId in $_activePartitions.Keys)
{
    $replicas = Get-ServiceFabricReplica -PartitionId $partitionId
    foreach ($replica in $replicas)
    {
        if ($replica.NodeName -eq $NodeName) {
            $replicaId = $replica.ReplicaId.ToString()
            [void] $_activeReplicas.Add($partitionId.ToString().Replace("-", "") + "_" + $replicaId)
        }
    }
}

$_checkpointFileExtensions = New-Object System.Collections.Generic.HashSet[string]
[void] $_checkpointFileExtensions.Add(".sfk");
[void] $_checkpointFileExtensions.Add(".sfv");
[void] $_checkpointFileExtensions.Add(".sfm");
[void] $_checkpointFileExtensions.Add(".sfc");

$_forceRemovedReplicasToFilesMap = GetForceRemovedReplicaToFilesMap -PartitonReplicaIdsSet $_activeReplicas `
                                    -WorkDirectoriesContent $_workDirectoriesContent -CheckpointFileExtensions $_checkpointFileExtensions

$Verbose = $false
if ($PSBoundParameters.ContainsKey('Verbose'))
{
    $Verbose = $PsBoundParameters.Get_Item('Verbose')
}

PrintLeakedContent -ForceRemovedReplicasToFilesMap $_forceRemovedReplicasToFilesMap `
        -PartitionDescriptions $_activePartitions -CheckpointFileExtensions $_checkpointFileExtensions

# Return either if there are no leaked files to delete or if WhatIf flag is set
if (($_forceRemovedReplicasToFilesMap.Count -eq 0) -or $WhatIf)
{
    return
}

# Get confirmation before actually deleting
$input = Read-Host "Are you sure you want to perform this action? `nYes[Y] No[N]"
$lowerCaseInput = $input.ToLower()
if ($lowerCaseInput -ne "y" -and $lowerCaseInput -ne "yes" -and $lowerCaseInput -ne "n" -and $lowerCaseInput -ne "no")
{
    Write-Output "Incorrect Choice! Action Aborted."
    return
}

if ($lowerCaseInput -eq "n" -or $lowerCaseInput -eq "no")
{
    return
}

# Delete all leaked files
foreach ($partitionReplicaIds in $_forceRemovedReplicasToFilesMap.Keys)
{
    $replicaRemovedInfo = GetReplicaDescription -PartitionReplicaIds $partitionReplicaIds -PartitionDescriptionMap $_activePartitions
    $leakedFilesAndFoldersInfo = "Removing files and folders corresponding to {0}" -f $replicaRemovedInfo
    Write-Output $leakedFilesAndFoldersInfo

    $paths = $_forceRemovedReplicasToFilesMap[$partitionReplicaIds]
    foreach ($path in $paths)
    {
        if ((Get-Item $path) -is [System.IO.DirectoryInfo])
        {
            RemoveCheckpointFilesFromDirectory -CheckpointFilesDirectory $path -CheckpointFileExtensions $_checkpointFileExtensions

            if ((Get-ChildItem $path | Measure-Object).Count -eq 0)
            {
                Remove-Item $path
            }
        }
        else
        {
            $fileRemovedInfo = "Removing {0}" -f $path
            Write-Verbose $fileRemovedInfo

            Remove-Item $path
        }
    }
}