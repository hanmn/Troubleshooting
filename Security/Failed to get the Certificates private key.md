## [Symptoms]
Entries  in the SF Traces and in the Microsoft-ServiceFabric Admin event logs:

    CryptAcquireCertificatePrivateKey failed. Error:0x80090014
    ----------------
    Can't get private key filename for certificate. Error: 0x80090014
    ----------------
    All tries to get private key filename failed.
    ----------------
    Failed to get the Certificate's private key. Thumbprint:AzureServiceFabric-AnonymousClient. Error: E_FAIL
    ----------------
    Can't find anonymous certificate. ErrorCode: E_FAIL
    ----------------
    Error at AclAnonymousCertificate, ErrorCode E_FAIL

## [Analysis]
 
* Checked into the nodes we can see the Certificate is present in all nodes and NetworkService account has Read rights on the Private Key:
 
* The PID for the errors in the traces is for FabricFAS.exe

Explanation according to PG:
This AnonymousClient certificate is generated for unsecure clusters. We are aware of this issue and this shouldn’t affect functionality of any SF component and just shows up as warning in traces.

In another words, you can safely ignore those warnings.
