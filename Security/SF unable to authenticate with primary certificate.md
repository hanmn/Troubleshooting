# Service Fabric unable to authenticate with primary certificate

## **Symptom**
- After adding a new secondary certificate you are now unable to authenticate with the original Primary certificate
    - This is regardless if the older certificate is in the primary or secondary cert position
    - Event logs may show FABRIC_E_SERVER_AUTHENTICATION_FAILED: 0x80092012

## **Cause**
- By design
- Starting with Service fabric 5.7 a design change was made to help simplify the certificate rollover process.  This changed the default behavior to automatically use the certificate with the furthest expiration (in the future) for authentication.

## **Resolution**
- Use the certificate with furthest expiration date for authentication
- Or you can revert to the old algorithm by using following command

```PowerShell
Set-AzureRmServiceFabricSetting -ResourceGroupName rgname -Name clustername -Section "Security" -Parameter "UseSecondaryIfNewer" -Value "false"
```

## **References**
- <https://github.com/Azure/service-fabric-issues/issues/517>


Repro:

```PowerShell
Connect-ServiceFabricCluster -ConnectionEndpoint sampleCluster.northeurope.cloudapp.azure.com:19000 -FindType FindByThumbprint -FindValue 967d398e239f79464b9a012345678901234567890 -X509Credential -ServerCertThumbprint 967d398e239f79464b9a012345678901234567890 -StoreLocation CurrentUser -StoreName My

    WARNING: Failed to contact Naming Service. Attempting to contact Failover Manager Service...
    WARNING: Failed to contact Failover Manager Service, Attempting to contact FMM...
    False
    Connect-ServiceFabricCluster : FABRIC_E_SERVER_AUTHENTICATION_FAILED: 0x80092012
    At line:1 char:1
    + Connect-ServiceFabricCluster -ConnectionEndpoint sampleCluster.northeu ...
```
