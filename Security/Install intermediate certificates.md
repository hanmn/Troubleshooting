# Install intermediate certificates in a Service Fabric cluster

Currently SF does not accept .CER or P7B certificates uploaded to keyvault.  
Missing intermediate can be installed to each nodetype using a [customscriptextension](https://blogs.technet.microsoft.com/stefan_stranger/2017/07/31/using-azure-custom-script-extension-to-execute-scripts-on-azure-vms/ "Examples of CustomScriptExtensions and DSC") to avoid SSL chain errors 

Upload the script and the intermediates to a storage account and add a CustomScriptExtension extension

```json
    "virtualMachineProfile": {
        "extensionProfile": {
            "extensions": [
            {
                "type": "Microsoft.Compute/virtualMachines/extensions",
                "name": "InstallCertificates",

                "properties": {
                    "publisher": "Microsoft.Compute",
                    "type": "CustomScriptExtension",
                    "typeHandlerVersion": "1.8",
                    "autoUpgradeMinorVersion": true,
                    "settings": {
                        "fileUris": [
                            "https://examplestorage1.blob.core.windows.net/sfdeploy/certinst.ps1"
                        ],
                        "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File certinst.ps1"
                    }
                }
            },
```

Example contents of the certinst.ps1 PowerShell script 

```PowerShell
    function Install-IntermediateCertificateFromUrl ($certurl)
    {
        $bytes = (Invoke-WebRequest $certurl -UseBasicParsing).Content
     
        $store = new-object System.Security.Cryptography.X509Certificates.X509Store "CA", "LocalMachine"
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
     
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$bytes
        $store.Add($cert)
        $store.Close()
    }
    
    #intermediate cert urls  
    $cert1url = "https://examplestorage1.blob.core.windows.net/sfdeploy/abccag2.crt"
    $cert2url = "https://examplestorage1.blob.core.windows.net/sfdeploy/defcag2.crt"
    ## or download directly from the distribution points provided in Authority Info Access Extensions
    
    #$cert1url = "http://trust.certglobal.com/abccag2.crt"
    #$cert2url = "https://www.sample.nl/fileadmin/PKI/PKI_certifcaten/defcag2.crt"
    
    Install-IntermediateCertificateFromUrl $cert1url
    Install-IntermediateCertificateFromUrl $cert2url
```