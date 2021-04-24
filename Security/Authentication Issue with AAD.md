## Symptom
AAD Authentication fails on SFX (Service Fabric Explorer).

According to the https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-creation-via-arm#assign-users-to-roles, users should be assigned to ‘ReadOnly’ or 'Admin' role, any other will be invalid.

In this case CSS reviewed the traces and noticed where the user was assigned to ‘ReadWriteUser’ group, and therfore it breaks due to the wrong role assignment.  Mitigate by fixing the user configuration to be either ReadOnly or Admin.

| Date | Time | Type | Process | Thread | Text |
|---|---|---|---|---|---|
| 2018-5-11 | 00:58:11.740	| SystemFabric.AAD.Server	| 980	  | 3580	| Claim: name: xxxx xxxx |
| 2018-5-11 | 00:58:11.740	| SystemFabric.AAD.Server	| 980	  | 3580	| Claim: nonce: 90b47fd2-eea2-45c7-9973-96bbb73e2f83 |
| 2018-5-11 | 00:58:11.740	| SystemFabric.AAD.Server	| 980	  | 3580	| Claim: http://schemas.microsoft.com/identity/claims/objectidentifier: d954c3a1-d94d-46f5-b252-08cb229047b2 |
| 2018-5-11 | 00:58:11.740	| SystemFabric.AAD.Server	| 980	  | 3580	| Claim: onprem_sid: S-1-5-21-2127521184-1604012920-1887927527-14735567 |
| 2018-5-11 | 00:58:11.740	| SystemFabric.AAD.Server	| 980	  | 3580	| Claim: http://schemas.microsoft.com/ws/2008/06/identity/claims/role: ReadWriteUser |
| 2018-5-11 | 00:58:11.740	| General.Aad::ServerWrapper	| 980	| 3580	| IsAdminRole failed: issuer=https://sts.windows.net/72f988bf-86f1-41af-91ab-2d7cd011db47/ audience=3c1beb77-e0ed-43d8-be02-569450b84d2f roleClaim=http://schemas.microsoft.com/ws/2008/06/identity/claims/role cert=https://login.microsoftonline.com/72f988bf-86f1-41af-91ab-2d7cd011db47/federationmetadata/2007-06/federationmetadata.xml error=System.IdentityModel.Tokens.SecurityTokenValidationException: Invalid role: http://schemas.microsoft.com/ws/2008/06/identity/claims/role=ReadWriteUser at System.Fabric.AzureActiveDirectory.Server.ServerUtility.Validate(String expectedIssuer, String expectedAudience, String expectedRoleClaimKey, String expectedAdminRoleValue, String expectedUserRoleValue, String certEndpoint, Int64 certRolloverIntervalTicks, String jwt) at IsAdminRole(Char* expectedIssuer, Char* expectedAudience, Char* expectedRoleClaimKey, Char* expectedAdminRoleValue, Char* expectedUserRoleValue, Char* certEndpoint, Int64 certRolloverCheckIntervalTicks, Char* jwt, Boolean* isAdmin, Int32* expirationSeconds, Char* errorMessageBuffer, Int32 errorMessageBufferSize) |
 
 