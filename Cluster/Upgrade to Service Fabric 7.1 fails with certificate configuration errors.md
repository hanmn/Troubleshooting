# Upgrade to Service Fabric 7.1 fails with certificate configuration errors

Upgrade to Service Fabric 7.1 fails and rolls back with application health errors trying to configure application certificates.

## Symptom

Certificate configuration error is highlighted in a sample output below. The cause of the failure can be found in SFX under the details tab for the cluster.

### UNHEALTHY EVALUATIONS (UPGRADE)

Kind | Health State | Description
-----|--------------|------------
Applications | Error  | 1% (1/100) applications are unhealthy. The evaluation tolerates 0% unhealthy applications.
&nbsp;Application | Error | Application 'fabric:/Application' is in Error. |
| &nbsp;&nbsp;DeployedApplications | Error | 100% (1/1) deployed applications are unhealthy. The evaluation tolerates 0% unhealthy deployed applications.
&nbsp;&nbsp;&nbsp;DeployedApplication | Error | Deployed application on node 'NodeName' is in Error.
&nbsp;&nbsp;&nbsp;&nbsp;**Event** | **Error** | **'System.Hosting' reported Error for property 'Activation:1.0'. There was an error during activation.Failed to configure certificate permissions. Error E_FAIL.**
&nbsp;&nbsp;&nbsp;&nbsp;DeployedServicePackages | Error  | 100% (1/1) deployed service packages are unhealthy.
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;DeployedServicePackage | Error  | Service package for manifest 'ServicePkg' and service package activation ID '' is in Error.
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Event | Error  | 'System.Hosting' reported Error for property 'ServiceTypeRegistration:ServiceType'. The ServiceType was disabled on the node.

## Cause

Permissions for all certificates specified for endpoints in the Application manifest are configured to give services access to these certificates. If service fabric does not find a certificate on the node, the configuration will fail resulting in activation failures.

We are investigating why activation succeeded in versions prior to 7.1, when the certificate was missing from the node.

## Mitigation

One of the following mitigation can be applied

1. Install all  certificates referenced in Application manifests on the nodes where the Application package can be deployed.
2. Provision any certificates required on the nodes. Modify Application manifest to remove references to certificates not required by application services and redeploy the application package.

After applying one of the above mitigation, retry upgrade to 7.1.
