# Application with dependency  on wastorage.dll crashes on Service Fabric runtime 6.4.617.9590

An known issue on Windows clusters with 6.4.617.9590 runtime has been identified which causes applications with a dependency on wastorage.dll to crash.

## Symptoms
- Application crash due to dependency load failure for wastorage.dll.
- This may also cause application upgrades to fail if this component is in the initialization path.

**Conditions for this to happen:**
- Application has **wastorage.dll** in application package
- Clusters is currently running version 6.4.617.9590
- Application is upgraded to a new app/code package version

## Root Cause Analysis
- Service Fabric Clusters running on the 6.4.617.9590 runtime have wastorage.dll added in our runtime dependencies, therefore we will automatically strip wastorage.dll from applications packages being deployed.
- If the version of wastorage.dll in the customers application package doesn’t match the Service Fabric runtime's version of wastorage.dll(3.2.2) the customers application will crash continuously.
- Analysis of the exception (crash dump analysis) will show it is failing to load wastorage.dll.

## Possible Mitigations
- Downgrade the cluster to latest 6.3, this will prevent the wastorage.dll from being stripped out.
- If the previous version of the application is still provisioned the customer may be able to downgrade to their previous version(deployed prior to when the Cluster was upgraded to the 6.4 runtime) since it should still have the wastorage.dll present. The application should be able to load it from the app folder, though there may still be load order issues.

## Additional information
The Service Fabric team is planning to fix this in 6.4 CU1

**Update:** A fix is being rolled out in 6.4.621.9590: https://blogs.msdn.microsoft.com/azureservicefabric/2018/12/12/azure-service-fabric-6-4-refresh-for-windows-clusters/
