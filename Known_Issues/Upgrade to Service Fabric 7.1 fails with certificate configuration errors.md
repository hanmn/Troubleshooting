# Application with dependency  on wastorage.dll crashes on Service Fabric runtime 6.4.617.9590

Upgrade to Service Fabric 7.1 fails and rolls back with application health errors trying to configure application certificates.

## Symptoms
- Certificate configuration error is highlighted in a sample output below. The cause of the failure can be found in SFX under the details tab for the cluster.

| Kind | Health State | Description | 
|---|---|---|
| Applications | Error | 1% (1/100) applications are unhealthy. The evaluation tolerates 0% unhealthy applications. |
|  Application  | Error | Application 'fabric:/Application' is in Error. |
|   Deployed Applications | Error | 100% (1/1) deployed applications are unhealthy. The evaluation tolerates 0% unhealthy deployed applications. |
|    Deployed Application | Error  | Deployed application on node 'NodeName' is in Error. |
|    **Event** | **Error** | **'System.Hosting' reported Error for property 'Activation:1.0'. There was an error during activation.Failed to configure certificate permissions. Error E_FAIL.** |
|    DeployedServicePackages | Error | 100% (1/1) deployed service packages are unhealthy. |
|     DeployedServicePackage | Error | Service package for manifest 'ServicePkg' and service package activation ID '' is in Error. |
|      Event | Error |   |
|  |  |  |


## Root Cause Analysis
- All certificates specified for endpoints in the Application manifest are configured to give services access to these certificates. If service fabric does not find the certificate on the node, it will fail the activation process
- Prior to 7.1, if a certificate was not found, the error was ignored and caused failures later in the activation process with a cryptic error. Starting from 7.1, all certificates mentioned in the Application Manifest are required to be on all the nodes where the application is deployed, independent of whether the certificate is used by the services. 

## Possible Mitigations

One of the following mitigation can be applied

1. Install all certificates referenced in Application manifests on all of the nodetypes where the Application package can be deployed.
2. Provision any certificates required on the nodes. Modify Application manifest to remove references to certificates not required by application services and redeploy the application package.

After applying one of the above mitigation, retry upgrade to 7.1


## Additional information

