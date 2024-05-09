# How to change Storage Account for Service Fabric Logs in Azure

Changing storage account used for Service Fabric Logs requires two ARM template deployments. 

## Deployment 1

First deployment adds reference to new storage account key in Service Fabric VM Extension in change 1 and in Service Fabric resource in change 2. Please ensure that you have configured two storage account keys and one of them is pointing to the new storage account. You may have to make two changes as following. 

### Change 1
* In the Service Fabric VM Extension section, make sure you have configured two storage keys. If you have configured only one key  ‘StorageAccountKey1’, add a second key ‘StorageAccountKey2’.

* Update the ‘StorageAccountKey2’ to refer to the new storage account key. This change will ensure that the new storage account key is made available on the node via Service Fabric VM extension.

<pre><code>"StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(<b>oldStorageAccount</b>)),'2015-05-01-preview').key1]",

"StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(<b>newStorageAccount</b>)),'2015-05-01-preview').key2]"
</code></pre>

### Change 2

* If you were not using two keys, then add protectedAccountKeyName2 in ‘diagnosticsStorageAccountConfig’ section of the Service Fabric resource, while keeping the rest unchanged.

* Set the value of ‘protectedAccountKeyName2’ to ‘StorageAccountKey2’.

* Keep the Endpoint fields unchanged so that they continue to point to the old storage account.

* *Note:* To support protectedAccountKeyName2, Microsoft.ServiceFabric/clusters requires api version **2020-03-01**

<pre><code>"diagnosticsStorageAccountConfig": {
     
    "protectedAccountKeyName2": "StorageAccountKey2"
		
    …
}
</code></pre>


## Deployment 2

Second deployment adds new storage account information in Service Fabric resource in change 1 and removes reference to old storage account key in Service Fabric VM Extension in *Optional* change 2. In the second deployment switch the Endpoint properties to use the new storage account key. Optionally you can remove the reference to the old storage account key from the template.

### Change 1

* Change diagnosticsStorageAccountConfig in Service Fabric resource to use the new storage account. 

* *Note:* To support protectedAccountKeyName2, Microsoft.ServiceFabric/clusters requires api version **2020-03-01**

<pre><code>"diagnosticsStorageAccountConfig": {
    "blobEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters(<b>newStorageAccount</b>)), variables('storageApiVersion')).primaryEndpoints.blob]",
    "protectedAccountKeyName": "StorageAccountKey1",
    "protectedAccountKeyName2": "StorageAccountKey2",
    "queueEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters(<b>newStorageAccount</b>)), variables('storageApiVersion')).primaryEndpoints.queue]",
    "storageAccountName": "parameters(<b>newStorageAccount</b>)",
    "tableEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters(<b>newStorageAccount</b>)), variables('storageApiVersion')).primaryEndpoints.table]"
}
</code></pre>

### *Optional* Change 2

* This change is optional and can be done later in a separate deployment. 
* Remove the reference to the old storage account from Service Fabric VM Extension section by updating protectedSettings of Service Fabric VM Extension Profile as following.
<pre><code>"StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(<b>newStorageAccount</b>)),'2015-05-01-preview').key1]",

"StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(<b>newStorageAccount</b>)),'2015-05-01-preview').key2]"
</code></pre>
