# FabricNode Certificate Expiration

[Issue](#Issue)  
[Health State](#Health-State)  
[Description](#Description)  
[Cause](#Cause)  
[Mitigation](#Mitigation)  
[Resolution](#Resolution)  
[Reference](#Reference)  

## Issue

Service Fabric Cluster Nodes Health Events Warnings for cluster, server, and client certificates.

## Health State

Warning

## Description

```text
System.FabricNode	Certificate_cluster	Mon, 11 May 2020 08:43:09 GMT	Infinity	132336601893388932	false	false
Certificate expiration: thumbprint = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx, expiration = 2020-06-07 18:22:33.000, remaining lifetime is 27:9:39:23.661, please refresh ahead of time to avoid catastrophic failure. Warning threshold Security/CertificateExpirySafetyMargin is configured at 30:0:00:00.000, if needed, you can adjust it to fit your refresh process.
```

## Cause

A warning will be displayed when certificate expiration time is below threshold. Default threshold is 30 days.

**NOTE: It is critical to update certificate before expiration and to allow a time buffer in case update fails.**

## Mitigation

If certificate is not expired, renew certificate before expiration.
If certificate is near expiration and certificate cannot be renewed, depending on cluster configuration you may be able to allow continued access to cluster after expiration.  
See

## Resolution

Renew certificate.
If certificate is expired, see:

[Fix Expired Cluster Certificate Automated Script](../Security/Fix-Expired-Cluster-Certificate-Automated-Script.md)  
[Fix Expired Cluster Certificate Manual Steps](../Security/Fix-Expired-Cluster-Certificate-Manual-Steps.md)  
[How to recover from an Expired Cluster Certificate](../Security/How-to-recover-from-an-Expired-Cluster-Certificate.md)  

## Reference

https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security-update-certs-azure  
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security  
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-rollover-cert-cn  
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-change-cert-thumbprint-to-cn  
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-connect-to-secure-cluster  
