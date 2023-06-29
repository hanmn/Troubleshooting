# Installing dependancies on virtual machine scaleset nodes during or after deployment  

[Installing dependancies during cluster deployment](#Installing-dependancies-during-cluster-deployment)  
[Installing dependancies after cluster deployment](#Installing-dependancies-after-cluster-deployment)  
[Modify ARM Template to Add Custom Script Extension](#Modify-ARM-Template-to-Add-Custom-Script-Extension)  
[Modify ARM Template to Add extension sequencing on Service Fabric Extension](#Modify-ARM-Template-to-Add-extension-sequencing-on-Service-Fabric-Extension)  
[Reference](#Reference)

## Overview
There are multiple methods to deploy application dependancies. Desired State Configuration DSC, custom image, chef, cloud-init, Custom Script Extension CSE are some examples. With the introduction of Extension Sequencing on VM and VMSS extensions, greater control of dependancy installation can be performed. This may not work in all environments, configurations, or applications. Always test in non-production with same configuration, reliability, and durability first. See [virtual-machine-scale-sets-deploy-app](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-deploy-app) for different installation options.

## Installing dependancies during cluster deployment
Using an ARM Template with CSE and extension sequencing, a dependancy can be installed with a node restart if required, before installation of Service Fabric. This functionality is not directly available in the azure portal so, powershell, visual studio, devops, or other method should be used.

## Installing dependancies after cluster deployment
> ## :exclamation:NOTE: It is critical to use 'PATCH' instead of 'PUT' if modifying a deployed cluster! Failure to do so will break the cluster.

### Example high level steps from resources.azure.com
#### Navigate to nodetype under 'provicers' 'virtualMachineScaleSets'
![](../media/resourcemgr1.png)

#### Select 'Edit' at top of page to start editing
![](../media/resourcemgr2.png)

#### When finished editing template, select 'PATCH'
![](../media/resourcemgr7.png)

### Modify ARM Template to Add Custom Script Extension

Add new 'CustomScriptExtension' extension to 'Microsoft.Compute/virtualMachineScaleSets' 'extensions' array. In the following example, dotnet framework 4.8 is installed and node is restarted before installation of the Service Fabric extension. See [custom-script-windows](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows) for additional information.

```json
"virtualMachineProfile": {  //
  "extensionProfile": {     // existing
    "extensions": [         // 
      {
        "name": "CustomScriptExtension",
        "properties": {
          "publisher": "Microsoft.Compute",
          "type": "CustomScriptExtension",
          "typeHandlerVersion": "1.8",
          "autoUpgradeMinorVersion": true,
          "settings": {
          "fileUris": [
            "https://locusblobs.blob.core.windows.net/customscripts/install-netframework-48.ps1"
          ],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File .\\install-netframework-48.ps1 && cmd /c shutdown /r /t 0"
          }
        }
      },
```

### Modify ARM Template to Add extension sequencing on Service Fabric Extension

Add 'provisionAfterExtensions' array with 'CustomScriptExtension' in 'properties' section of 'ServiceFabric' extension. See [virtual-machine-scale-sets-extension-sequencing](https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-extension-sequencing) for additional information.

```json
,
{
    "name": "[concat(parameters('vmNodeType0Name'),'_ServiceFabricNode')]",
    "properties": {
        "provisionAfterExtensions": [   // 
            "CustomScriptExtension"     // insert for extension sequencing
        ],                              //
        "type": "ServiceFabricNode",
        "autoUpgradeMinorVersion": true,
        "protectedSettings": {
            "StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key1]",
            "StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('supportLogStorageAccountName')),'2015-05-01-preview').key2]"
        },
        "publisher": "Microsoft.Azure.ServiceFabric",
```

## Reference

### Example diff from changes using template.json generated from portal

```diff
diff --git a/serviceFabricInternal/configs/arm/sf-1nt-1n-1lb-portal-191013.json b/serviceFabricInternal/configs/arm/sf-1nt-1n-1lb-portal-191013.json
index 738fd29..982a1d2 100644
--- a/serviceFabricInternal/configs/arm/sf-1nt-1n-1lb-portal-191013.json
+++ b/serviceFabricInternal/configs/arm/sf-1nt-1n-1lb-portal-191013.json
@@ -457,9 +457,27 @@
                 "virtualMachineProfile": {
                     "extensionProfile": {
                         "extensions": [
+                            {
+                                "name": "CustomScriptExtension",
+                                "properties": {
+                                    "publisher": "Microsoft.Compute",
+                                    "type": "CustomScriptExtension",
+                                    "typeHandlerVersion": "1.8",
+                                    "autoUpgradeMinorVersion": true,
+                                    "settings": {
+                                    "fileUris": [
+                                        "https://locusblobs.blob.core.windows.net/customscripts/install-netframework-48.ps1"
+                                    ],
+                                    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File .\\install-netframework-48.ps1 && cmd /c shutdown /r /t 0"
+                                  }
+                                }
+                            },
                             {
                                 "name": "[concat(parameters('vmNodeType0Name'),'_ServiceFabricNode')]",
                                 "properties": {
+                                    "provisionAfterExtensions": [
+                                        "CustomScriptExtension"
+                                    ],
                                     "type": "ServiceFabricNode",
                                     "autoUpgradeMinorVersion": true,
                                     "protectedSettings": {
```
