# Scheduling task on virtual machine scale set  

>[Modify ARM Template to Add Custom Script Extension](#Modify-ARM-Template-to-Add-Custom-Script-Extension)  
>[Example](#Example)  
>>[template.json](#templatejson)  
>>[parameters.json](#parametersjson)  

## Overview  

There are multiple methods to configure scheduled tasks on windows scale sets. Desired State Configuration DSC and Custom Script Extension CSE are two common examples. Before determining method to use, verify task will always be configured regardless if scale set is scaled out, nodes are re-imaged, or cluster is redeployed. Using an ARM Template with CSE will ensure task is always configured and at the appropriate state. This example may not work in all environments or configurations. Always test in non-production with same configuration first.  

## Modify ARM Template to Add Custom Script Extension

Add new 'CustomScriptExtension' extension to 'Microsoft.Compute/virtualMachinescalesets' 'extensions' array in ARM template. See [custom script extension](https://docs.microsoft.com/azure/virtual-machines/extensions/custom-script-windows) for additional information on custom script extensions.  

### parameters section  

```json
"customScriptExtensionFile":{
    "type": "string",
    "defaultValue": "",
    "metadata": {
        "description": "powershell script file name and arguments for custom script extension to execute"
    }
},
"customScriptExtensionFileUri":{
    "type": "string",
    "defaultValue": "",
    "metadata": {
        "description": "uri of the script file for custom script extension to execute"
    }
},
```

### resources section  

```json
{
  "name": "CustomScriptExtension",
  "properties": {
    "publisher": "Microsoft.Compute",
    "type": "CustomScriptExtension",
    "typeHandlerVersion": "1.8",
    "autoUpgradeMinorVersion": true,
    "settings": {
    "fileUris": [
      "[parameters('customScriptExtensionFileUri')]"
    ],
      "commandToExecute": "[concat('powershell -ExecutionPolicy Unrestricted -File .\\', parameters('customScriptExtensionFile'))]"
    }
  }
},
```

## Example

In the following example, a scheduled task is created for the execution of configured script.'%Script storage uri%' is the uri location of the script and can be any uri that is accessible from scale set during deployment such as a github repository or blob storage.

Below are diffs from changes using template.json generated from portal after adding CustomScriptExtension.
The powershell script [../Scripts/schedule-task.ps1](../Scripts/schedule-task.ps1) is an example script that will configure scheduled task to execute configured script 'task.ps1'. To use schedule-task.ps1, copy script to '%script storage uri%'. In powershell, type 'help .\schedule-task.ps1 -full' for script argument information. RDP to node and use 'Task Scheduler' gui to verify / troubleshoot tasks.  

### template.json

```diff
diff --git a/internal/template/template.json b/internal/template/template.json
index f362926..ff080f0 100644
--- a/internal/template/template.json
+++ b/internal/template/template.json
@@ -2,6 +2,18 @@
     "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json",
     "contentVersion": "1.0.0.0",
     "parameters": {
+        "customScriptExtensionFile":{
+            "type": "string",
+            "defaultValue": "",
+            "metadata": {
+                "description": "powershell script file name and arguments for custom script extension to execute"
+            }
+        },
+        "customScriptExtensionFileUri":{
+            "type": "string",
+            "defaultValue": "",
+            "metadata": {
+                "description": "uri of the script file for custom script extension to execute"
+            }
+        },
         "clusterLocation": {
             "type": "string",
             "defaultValue": "westus",
@@ -457,9 +469,27 @@
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
+                                        "fileUris": [
+                                            "[parameters('customScriptExtensionFileUri')]"
+                                        ],
+                                        "commandToExecute": "[concat('powershell -ExecutionPolicy Unrestricted -File .\\', parameters('customScriptExtensionFile'))]"
+                                    }
+                                }
+                            },
```

### parameters.json

```diff
diff --git a/internal/template/parameters.json b/internal/template/parameters.json
index 289e771..e598691 100644
--- a/internal/template/parameters.json
+++ b/internal/template/parameters.json
@@ -2,6 +2,12 @@
     "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
     "contentVersion": "1.0.0.0",
     "parameters": {
+        "customScriptExtensionFile":{
+            "value": "schedule-task.ps1 -triggerFrequency weekly -start -overwrite -scriptFile https://{{ %script storage uri% }}/task.ps1"
+        },
+        "customScriptExtensionFileUri":{
+            "value": "https://{{ %script storage uri% }}/schedule-task.ps1"
+        },
         "clusterName": {
             "value": "sf-1nt-5n-cse"
         },
```
