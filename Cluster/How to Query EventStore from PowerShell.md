# How to Query Eventstore from PowerShell

## Example to get Cluster Eventsm including Fabric Upgrade history using the EventStore rest endpoint

- If your cluster is using a CA signed certificate you can simply make the Rest call

```PowerShell
    Invoke-RestMethod -Uri 'https://mycluster.westus.cloudapp.azure.com:19080/EventsStore/Cluster/Events?api-version=6.2-preview&StartTimeUtc=2018-08-01T00:00:00Z&EndTimeUtc=2018-08-14T18:00:00Z' -CertificateThumbprint '677244db4c0add5770904a4269c81a0269aba2f5'  -Method Get
```
- If you are using a self-signed certificate for your cluster cert, you will need to disable the certificate validation check.  **Security Note:** this will disable certificate validation for the entire PowerShell session.

```PowerShell
    $source = @"
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;

    public class SSLValidator
    {
        public SSLValidator() {}
        private bool OnValidateCertificate(object sender, X509Certificate certificate, X509Chain chain,
                                                    SslPolicyErrors sslPolicyErrors)
        {
            return true;
        }
        public void OverrideValidation()
        {
            ServicePointManager.ServerCertificateValidationCallback =
                OnValidateCertificate;
            ServicePointManager.Expect100Continue = true;
        }
    }
    "@

    Add-Type -TypeDefinition $source

    $validation = new-object SSLValidator 
    $validation.OverrideValidation()

    Invoke-RestMethod -Uri 'https://mycluster.westus.cloudapp.azure.com:19080/EventsStore/Cluster/Events?api-version=6.2-preview&StartTimeUtc=2018-08-01T00:00:00Z&EndTimeUtc=2018-08-14T18:00:00Z' -CertificateThumbprint '677244db4c0add5770904a4269c81a0269aba2f5'  -Method Get
```
