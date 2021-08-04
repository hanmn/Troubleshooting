## Use the <https://resources.azure.com> to add the Secondary Certificate

In the MSDN article <https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security-update-certs-azure#add-a-secondary-certificate-and-swap-it-to-be-the-primary-using-resource-manager-powershell> it's mentioned that secondary cluster certificate cannot be added through the Azure portal. You have to use Azure powershell for that.

The feature to add a secondary certificate may be added back to portal, but for now, you will have to use the ARM template [PowerShell ARM Template Deployment - Swap certificates](./PowerShell%20ARM%20Template%20Deployment%20-%20Swap%20certificates.md) or <https://resources.azure.com> to add the secondary certificate.

 

 

1. Make sure you push the 2nd cert to the VMSS already, you can follow [Add new cert to VMSS](.\Add_New_Cert_To_VMMS.ps1)

2. Go to <https://resources.azure.com> and find your subscription \-- \> resource group \-- \> providers/Microsoft.Compute/virtualMachineScaleSets \-- \> your VMSS

![Azure Resource Explorer](../media/resourcemgr1.png)

3. enable \"Edit\" and \"Read/Write\" permission

![Read/Write](../media/resourcemgr2.png)

 

Step 4: add the following \"certificateSecondary\" settings in VMSS/extensionProfile/extensions:

 

![
\"extensionProfi1e\": {
extensions \'
properties\" •
\'publisher\": \"Microsoft . Azure . ServiceFabric\",
\"type\": \"ServiceFabricNode\" ,
\"...\" •
\"certificate\": {
\"thumbprint\" •
. \"5F61FFC7F9DB19A5EC2819DDICD671B7A3D8671B\" ,
\"x509StoreName\" : \"My\"
\"certificateSecondary\"
\"your new thumbprint \" •
\" x509StoreName \" : ](../media/resourcemgr3.png)

* And then scroll back to the top of the page and click PUT.

5. Wait for VMSS Status under the resource group is \"Succeeded\" before update the Service Fabric cluster settings:

![WordCount
Virtual machine scale set
p Search (Ctr/+/)
Overview
Status
Succeeded
](../media/resourcemgr4.png)

6. Repeat steps 2 and 3 for the Microsoft.ServiceFabric provider for your cluster

* Adding \"thumbprintSecondary\": \"656A78764F57E938BBBA08377F8D9C6DFBE19BA7\" setting

![Azure Resource Explorer • providers/ microsoft . ServiceFabric/ clusters/hughsftest \" 
\"thumbprint\" •
. \"5F61FFC7F9DB19A5EC2819DDICD671B7A3D8671B\" ,
\"thumbprintSecondary\" •
. \"656A78764F57E938BBBAe8377F8D9C6DFBE19BA7i%
](../media/resourcemgr5.png)

 

Step 8: wait for the SF cluster Updating the secondary certificate to complete

![Azure Portal •  Service Fabric cluster  • status  • Updating user certificate](../media/resourcemgr6.png)

* [Why do cluster upgrades take so long](./Why%20do%20cluster%20upgrades%20take%20so%20long.md)
 

Step 9: [Swap Primary and Secondary certificates](./Swap%20Primary%20and%20Secondary%20certificates.md)
