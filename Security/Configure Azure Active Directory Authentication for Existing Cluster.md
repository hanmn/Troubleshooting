## Configure Azure Active Directory Authentication for Existing Cluster

### Configure Azure Active Directory Authentication for new cluster
To create a cluster from scratch using Azure Active Directory, please follow this MSDN document, which covers creating the AAD App, creating users, and assigning those users to roles on the app.
https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-creation-setup-aad

    i. NOTE for internal Microsoft employees: if the cluster is configured in the Microsoft Tenant you must have IT authorize a Security Group to the "Admin" role
https://microsoft.sharepoint.com/teams/CorpSTS/Microsoftcom%20AAD%20onboarding%20support/Home.aspx
(Or try https://microsoft.sharepoint.com/teams/CSEOAAD)

### Steps to configure AAD Auth on existing cluster from [http://portal.azure.com](http://portal.azure.com) 
**Note**: This is only possible for Windows clusters. Linux clusters must be configured for AAD before being created.

1. Create new AAD directory (or use your existing AAD - Note: you must be an Admin for your company) - 
    a. For testing I created a new Directory called sedeastaad
        1. if you are using an existing AAD you can skip to step #3

2. Go to Azure Active Directory in Azure Portal.

3. Create a new Directory.

4. Create couple of new users
    a. foo@company.domain.com
    b. bar@company.domain.com 

5. Login to AAD account using one of the user accounts above

    PS C:\WINDOWS\system32> Login-AzureRmAccount

    Environment           : AzureCloud
    Account               : foo@sfaaddomain.onmicrosoft.com
    TenantId              : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    SubscriptionId        : 
    SubscriptionName      : 
    CurrentStorageAccount :  

6. Run SetupApplications script (download scripts: [MicrosoftAzureServiceFabric-AADHelpers](https://github.com/robotechredmond/Azure-PowerShell-Snippets/tree/master/MicrosoftAzureServiceFabric-AADHelpers/AADTool) , 

    Right-click the zip file, select Properties, select the "Unblock" check box, and then click Apply.
    PS C:\MicrosoftAzureServiceFabric-AADHelpers> .\SetupApplications.ps1 -TenantId XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX -ClusterName aadcluster -WebApplicationReplyUrl "https://mycluster.centralindia.cloudapp.azure.com:19080/Explorer/index.html"
    
**Here, is example output (with id's to see which field is mapped to which property in the ARM template).**

```PowerShell
    TenantId =  42cdd38a-XXXX-XXXX-XXXX-919fe11ea28d
    Web Application Created: c06877c1-XXXX-XXXX-XXXX-13732db46a9c
    Native Client Application Created: 7c9f8000-XXXX-XXXX-XXXX-df13e9b08470
```

  | Name | Value |
  |---|---|
  |TenantId                       |42cdd38a-XXXX-XXXX-XXXX-919fe11ea28d|
  |WebAppId                       |c06877c1-XXXX-XXXX-XXXX-13732db46a9c|
  |NativeClientAppId              |7c9f8000-XXXX-XXXX-XXXX-df13e9b08470|
  |ServicePrincipalId             |5e994fd7-XXXX-XXXX-XXXX-ab44178c1568|

```json
    -----ARM template-----
    "azureActiveDirectory": {
        "tenantId":"42cdd38a-XXXX-XXXX-XXXX-919fe11ea28d",
        "clusterApplication":"c06877c1-XXXX-XXXX-XXXX-13732db46a9c",
        "clientApplication":"7c9f8000-XXXX-XXXX-XXXX-df13e9b08470"
    },
```

7. Now, from portal under the AAD, go to Enterprise applications

8. Select All applications option

9. Select Show All Applications and apply.

10. Select the Application Cluster(aadcluster_Cluster).

11. Go to Users and groups and select Add user option.

12. Select the user and give it the Admin role. (Must be Admin on the tenant, else contact your IT department authorize a Security Group to the "Admin" role)

13. Now, go back to the Azure portal and select Service Fabric, and go to security option and click on Add.

14. Select, authentication type as Azure Active Directory and pass all the details(Tenant ID, Cluster application and Client application).

15. Now, you can see the message: Cluster is updating user configuration. (It may take some time to complete)

16. Once the update complete and if you try to access the Service Fabric Explorer, you will see an error like AADSTS50105 - "The signed in user is not assigned to a role for the application".

17. To overcome this you must add users to a Role, go to App Registrations and select the Cluster, then add your user to the Admin role

18. Now, try to access you cluster: https://mycluster.centralindia.cloudapp.azure.com:19080/Explorer 
    you will be able to access Service Fabric explorer from your AAD user.
    
    
### FAQ

* How to connect to a Service Fabric cluster over PowerShell with AAD authentication

```PowerShell
    $ClusterName= "sedwest.westus.cloudapp.azure.com:19000"
    $ServerCertThumprint = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    Connect-ServiceFabricCluster -ConnectionEndpoint $ClusterName `
    -ServerCertThumbprint $ServerCertThumprint `
    -AzureActiveDirectory
```

**Note**: If the Cluster Certificate was issued to a custom domain you need to use the custom domain URL into $ClusterName (e.g. $ClusterName= "villar.westus.lvillar.com:19000") otherwise you will get the error:

    WARNING: Failed to contact Naming Service. Attempting to contact Failover Manager Service...
    WARNING: Failed to contact Failover Manager Service, Attempting to contact FMM...
    False
    Connect-ServiceFabricCluster : FABRIC_E_SERVER_AUTHENTICATION_FAILED: 
    CertificateNotMatched
    At line:17 char:1
    + Connect-ServiceFabricCluster -AzureActiveDirectory -ConnectionEndpoin ...
    + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        + CategoryInfo          : InvalidOperation: (:) [Connect-ServiceFabricClus 
    ter], FabricServerAuthenticationFailedException
        + FullyQualifiedErrorId : TestClusterConnectionErrorId,Microsoft.ServiceFa 
    bric.Powershell.ConnectCluster

* Workaround to the above:
    * Create a PowerShell.exe.config
    * Can configure https://docs.microsoft.com/en-us/dotnet/framework/configure-apps/file-schema/network/servicepointmanager-element-network-settings
    * Set checkCertificateName="false" 

>> try add "Windows Azure Active Directory" under "Permissions to other applications" in "Cluster Application". And enable "sign in and read user profile" delegated permissions.


