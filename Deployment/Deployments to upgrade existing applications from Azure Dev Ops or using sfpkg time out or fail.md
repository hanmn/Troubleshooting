# Deployments to upgrade existing applications from Azure Dev Ops or using sfpkg time out or fail

## Symptom

Deployment from Azure Dev Ops times out for application that were successfully deployed previously. Further deployments fail.

In SFX, one of the Application types shows a message similar to the following

Name | Version / Message | Status
-----|-------------------|-------
ApplicationType | ApplicationType Version | Provisioning
| | Downloading <https://contoso.blob.core.windows.net/00000000-0000-0000-0000-000000000000/pkg/ServiceTypePackageName.sfpkg?...> : 5304320 bytes received, 9140238 expected (58.0%).

## Cause

Known bug in 7.0 version of SF. Fixed in SF version 7.0.472.9590 and later.

## Mitigation

* In SFX, locate ClusterManagerService under System.
* Expand the replicas for ClusterManagerService and note down the node with the primary replica
* RDP to the VM with the ClusterManagerService primary replica (If RDP access is not available, restart VM)
* Stop Imagebuilder.exe service
* Redeploy the failed deployment
