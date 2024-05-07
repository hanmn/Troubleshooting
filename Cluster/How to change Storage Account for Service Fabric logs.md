##  How to change Storage Account for Service Fabric Logs in Azure

Changing storage account used for Service Fabric Logs requires two ARM template deployments. 

First deployment adds reference to new storage account key in Service Fabric VM Extension in step 1 and in Service Fabric resource in step 2. 

Second deployment removes reference to old storage account key in Service Fabric VM Extension in *Optional* step 1 and adds new storage account information in Service Fabric resource in step 2.

## Deployment 1

1. Change Service Fabric VM Extension to have StorageAccountKey2 with the key of the new storage account while StorageAccontKey1 is kept the same pointing to the old storage account. Update the **protectedSettings** of Service Fabric VM Extension Profile using ARM template deployment as following. 

<pre><code>"StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(<b>oldStorageAccount</b>)),'2015-05-01-preview').key1]",

"StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(<b>newStorageAccount</b>)),'2015-05-01-preview').key2]"
</code></pre>

2. Add protectedAccountKeyName2 in Service Fabric resource diagnosticsStorageAccountConfig while keeping the rest unchanged as following. (To support protectedAccountKeyName2, Microsoft.ServiceFabric/clusters requires api version **2020-03-01**) <br />*Note: If protectedAccountKeyName2 already exists then replace it with new storage account key.*
<pre><code>"diagnosticsStorageAccountConfig": {
     
    "protectedAccountKeyName2": "StorageAccountKey2"
		
    …
}
</code></pre>

3. Deploy the ARM template.

## Deployment 2

1. *Optional and can be done later in another deployment*:  Change Service Fabric VM Extension to point to new storage account by updating **protectedSettings** of Service Fabric VM Extension Profile as following.
<pre><code>"StorageAccountKey1": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(<b>newStorageAccount</b>)),'2015-05-01-preview').key1]",

"StorageAccountKey2": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters(<b>newStorageAccount</b>)),'2015-05-01-preview').key2]"
</code></pre>

2. Change diagnosticsStorageAccountConfig in Service Fabric resource to use the new storage account. (To support protectedAccountKeyName2, Microsoft.ServiceFabric/clusters requires api version **2020-03-01**)
<pre><code>"diagnosticsStorageAccountConfig": {
    "blobEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters(<b>newStorageAccount</b>)), variables('storageApiVersion')).primaryEndpoints.blob]",
    "protectedAccountKeyName": "StorageAccountKey1",
    "protectedAccountKeyName2": "StorageAccountKey2",
    "queueEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters(<b>newStorageAccount</b>)), variables('storageApiVersion')).primaryEndpoints.queue]",
    "storageAccountName": "parameters(<b>newStorageAccount</b>)",
    "tableEndpoint": "[reference(concat('Microsoft.Storage/storageAccounts/', parameters(<b>newStorageAccount</b>)), variables('storageApiVersion')).primaryEndpoints.table]"
}
</code></pre>

3. Deploy the ARM template.