Customers using 3.1 SDK targeting v6.3 RTO cluster, sometimes might hit the upload issue where copy application package fails with Invalid argument

> Copy-ServiceFabricApplicationPackage -ApplicationPackagePath C:\temp\package\package\MyApplicationPkg
Using ImageStoreConnectionString='fabric:imageStore'
Copy-ServiceFabricApplicationPackage : Value does not fall within the expected range.
At line:1 char:1
+ Copy-ServiceFabricApplicationPackage -ApplicationPackagePath C:\temp...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Copy-ServiceFabricApplicationPackage], ArgumentException
    + FullyQualifiedErrorId : CopyApplicationPackageErrorId,Microsoft.ServiceFabric.Powershell.CopyApplicationPackage



Mitigation:

	1. Check the value of NamingService::MaxMessageSize on your cluster. If the value is anything other than default 4MB then it might cause this this issue.
	To mitigate, update the Naming:MessageSize to 4194304 (or delete that config entry) on your cluster.
	
	You can use resource.azure.com and navigate to your cluster and edit the settings as below and push it (PUT).

    "fabricSettings": [
      {
        "name": "NamingService",
        "parameters": [
          {
            "name": "MaxMessageSize",
            "value": "4194304"
          }
        ]
      }
    ],

NamingService::MaxMessageSize describes max message size (packet size) that can be used to communicate from client to cluster. Default in local is set to 4MB. So if your cluster has different value than default 4MB, there is no agreement between cluster and client resulting in InvalidArgument.

This has been fixed in 6.3 CU1 (3.2.176.9494 SDK). So it can also be mitigated by moving to SDK version above 3.2.176.9494.

	2. Use 3.2.176.9494 SDK which has this issue fixed


