You can create self-signed certificates easily using the following PowerShell cmdlet
	
	New-SelfSignedCertificate -NotBefore '2018-05-09' -NotAfter '2018-06-01' -DnsName www.domain-name.eastus.cloudapp.azure.com -CertStoreLocation Cert:\LocalMachine\My -Provider "Microsoft Strong Cryptographic Provider" -KeyExportPolicy ExportableEncrypted

Verify cert:
	Certutil -v -store my <thumbprint>


SF will not be able to extract and parse the certificate's private key if the certificate was created with an unsuitable CSP 
example:
	Provider = Microsoft Software Key Storage Provider
 
To dump cert details:
	Certutil -v -dump -store my <thumbprint>
	Certutil -v -dump certfilename.pfx > output.txt
