Issue:  Copy application package failed with access denied when trying to upload the package.

Traces:


2017-10-29 16:04:21.192	FileStoreService.ImpersonatedSMBCopyContext@15c6380e260	76728	19004	CopyFile: SourcePath:\\10.0.0.4\StoreShare_N0010\131537665370935284\Store\Compose_0\131537665354607235_12884901888_1.scripttest.backendPkg.Manifest.v0.xml, DestinationPath:D:\MCRoot\BinCache\bins\RunTests\log\ComposeDeploymentCommunication\test\TC\N0030\Fabric\work\Applications\__FabricSystem_App4294967295\work\Store\131537665489197547\Store\Compose_0\131537665354607235_12884901888_1.scripttest.backendPkg.Manifest.v0.xml, Error:E_ACCESSDENIED, ElapsedTime:20
2017-10-29 16:04:21.192	FileStoreService.ImpersonatedSMBCopyContext@15c6380e260	76728	19004	ImpersonateAndCopyFile for SourcePath:\\10.0.0.4\StoreShare_N0010\131537665370935284\Store\Compose_0\131537665354607235_12884901888_1.scripttest.backendPkg.Manifest.v0.xml, DestinationPath:D:\MCRoot\BinCache\bins\RunTests\log\ComposeDeploymentCommunication\test\TC\N0030\Fabric\work\Applications\__FabricSystem_App4294967295\work\Store\131537665489197547\Store\Compose_0\131537665354607235_12884901888_1.scripttest.backendPkg.Manifest.v0.xml failed: E_ACCESSDENIED.
2017-10-29 16:04:21.192	FileStoreService.ImpersonatedSMBCopyContext@15c6380e260	76728	19004	ImpersonateAndCopyFile for SourcePath:\\10.0.0.4\StoreShare_N0010\131537665370935284\Store\Compose_0\131537665354607235_12884901888_1.scripttest.backendPkg.Manifest.v0.xml, DestinationPath:D:\MCRoot\BinCache\bins\RunTests\log\ComposeDeploymentCommunication\test\TC\N0030\Fabric\work\Applications\__FabricSystem_App4294967295\work\Store\131537665489197547\Store\Compose_0\131537665354607235_12884901888_1.scripttest.backendPkg.Manifest.v0.xml failed: E_ACCESSDENIED. Have tried all access tokens.
2017-10-29 16:04:21.192	FileStoreService.ImpersonatedSMBCopyContext@15c6380e260	76728	19004	CopyFile: no new token is found. current token count: 1


Probable Issue:

The probable issue could be that local folder from which SMB share was created has SFAdministrators group and SFAllowedUsers group are removed from the ACL list. 

Image store(FSS) has been relying indirectly on SF groups permission (SFAdministrators group and SFAllowedUsers group ) which had FSS accounts. For yet to be determined reason ACLs for SF groups are not carried forward to some of the SF folders which also host image store. So this caused access denied while trying to access SMB share for uploading the application package.

The mitigation is to explicitly add ACLs to include FSSGroup_ffffffff (which contains FSS user accounts) and add ACLs for SFAdministrators group and SFAllowedUsers group.

From the image store point of view, the fix would be remove remove depenedency on the SF groups to provide access to the folder. We would explicitly ACL FSS group.

Affected Version: Before v6.2 CU3

Mitigation Steps:

	1. Run "net share" to determine the share local location.

StagingShare_vm0
             C:\ProgramData\SF\vm0\Fabric\work\Applications\__FabricSystem_App4294967295\work\Staging
                                             WindowsFabric share
StoreShare_vm0
             C:\ProgramData\SF\vm0\Fabric\work\Applications\__FabricSystem_App4294967295\work\Store
                                             WindowsFabric share


	2. Run "icacls.exe" on the local paths to check if SF group mentioned above was present.

C:\WINDOWS\system32>icacls.exe C:\ProgramData\SF\vm0\Fabric\work\Applications\__FabricSystem_App4294967295\work\Staging

C:\ProgramData\SF\vm0\Fabric\work\Applications\__FabricSystem_App4294967295\work\Staging NT AUTHORITY\SYSTEM:(OI)(CI)(F)
                                                                                         BUILTIN\Administrators:(OI)(CI)(F)
                                                                                         CREATOR OWNER:(OI)(CI)(IO)(F)
                                                                                         BUILTIN\Users:(OI)(CI)(RX)
                                                                                         BUILTIN\Users:(CI)(WD,AD,WEA,WA)
                                                                                         IYPSPC7\ServiceFabricAdministrators:(F)
                                                                                         IYPSPC7\ServiceFabricAdministrators:(OI)(CI)(IO)(F)
                                                                                         IYPSPC7\ServiceFabricAllowedUsers:(RX)
                                                                                         IYPSPC7\ServiceFabricAllowedUsers:(OI)(CI)(IO)(GR,GE)
                                                                                         NT AUTHORITY\SYSTEM:(OI)(CI)(IO)(F)
                                                                                         NT AUTHORITY\NETWORK SERVICE:(F)
                                                                                         NT AUTHORITY\NETWORK SERVICE:(OI)(CI)(IO)(F)
                                                                                         IYPSPC7\FSSGroupffffffff:(OI)(CI)(IO)(F)
                                                                                         IYPSPC7\FSSGroupffffffff:(F)
                                                                                         NT AUTHORITY\SYSTEM:(I)(OI)(CI)(F)
                                                                                         BUILTIN\Administrators:(I)(OI)(CI)(F)
                                                                                         CREATOR OWNER:(I)(OI)(CI)(IO)(F)
                                                                                         BUILTIN\Users:(I)(OI)(CI)(RX)
                                                                                         BUILTIN\Users:(I)(CI)(WD,AD,WEA,WA)
                                                                                         IYPSPC7\ServiceFabricAdministrators:(I)(F)
                                                                                         IYPSPC7\ServiceFabricAdministrators:(I)(OI)(CI)(IO)(F)
                                                                                         IYPSPC7\ServiceFabricAllowedUsers:(I)(RX)
                                                                                         IYPSPC7\ServiceFabricAllowedUsers:(I)(OI)(CI)(IO)(GR,GE)
                                                                                         NT AUTHORITY\SYSTEM:(I)(OI)(CI)(IO)(F)
                                                                                         NT AUTHORITY\NETWORK SERVICE:(I)(F)
                                                                                         NT AUTHORITY\NETWORK SERVICE:(I)(OI)(CI)(IO)(F)


 Note: The bolded groups ServiceFabricAdministrators, ServiceFabricAllowedUsers should be present.
From 6.3 (or 6.2 CU3) onwards you should see FSSGroupffffffff in that list too.
Bug # 12561821 Commit: https://msazure.visualstudio.com/DefaultCollection/One/Service%20Fabric/_git/WindowsFabric/commit/b79e2e09c4ce922f3ab2ef77f42caf6a1b482305

	
	3. a) If those accounts were missing, add those accounts with the correct permission as above. Now, test the copy application package again. Note: Staging and store path has different permissions for those accounts.
	
	b) If you see SIDs but without name, it is possible that it could be old SID for those accounts. Run the following command to check it out.

	Ø wmic group where sid='S-1-5-21-1494252980-3244581900-141412817-1000' get name
	No Instance(s) Available.

	If cmd reports no instance available, it means that those are older SIDs for those SF group accounts and those Sids can be deleted. Now add these new SF group accounts with permission listed above. Try uploading package again.
	
	For CSS team, Please also note when was the last Windows update ran and check with the customer if the issue started arising after Windows Update. Please mail sfimagestore with details.
	
	4. If the above step doesn't work, check any healthy node and add any missing accounts to the problematic node.
          Try upload again.

If none of the step mitigates the issue, please send a mail to sfimagestore with details of the above command along with Get-smbshare PS cmdlet.
