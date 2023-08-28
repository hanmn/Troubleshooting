# Remove-Unreferenced-Replica-Files

When a replica is force removed, corresponding checkpoint files are not removed from the file system. This tool removes leaked files (state manager, state provider and dedicated log files) given a node name.

**Parameters:**
1. NodeName: Name of the node from where the leaked files are being removed.
2. Verbose: Displays unreferenced files corresponding to leaked replicas.
3. WhatIf: Shows what would happen if the cmdlet runs.

**Examples:**
- Deletes all leaked files.

		.\Remove-UnreferencedReplicaFiles.ps1 
			-NodeName <nodeName>
	
- Shows leaked replicas indicating files corresponding to it would be deleted if the cmdlet runs.
	
		.\Remove-UnreferencedReplicaFiles.ps1 
			-NodeName <nodeName> 
			-WhatIf
		
- Deletes and displays leaked files corresponding to the removed replicas.

		.\Remove-UnreferencedReplicaFiles.ps1 
			-NodeName <nodeName> 
			-Verbose
