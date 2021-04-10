*If you have a certificate deployed to the VMSS but the application cannot access it (returns null) then it's possible the Private Key is not ACL'd correctly.  By default Service Fabric runs under NetworkService account, so you must ensure the private key is configured to allow this account to access it.*

*This example shows how to setup the Principle and set the ACL using SecurityAccessPolicies, from the ApplicationManifest.xml.  Two different certs are updated, an EndpointCertificate and a simple SecretsCertificate.*

*See more about this at https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-application-secret-management *

# Certificate-Configurations
# Private-Key-Permissions

---

<ApplicationManifest>
 …
 …
 …
 …
<Principals>
	<Users>
		<User Name="Service1" AccountType="NetworkService" />
	</Users>
</Principals>
<Policies>
	<SecurityAccessPolicies>
		<SecurityAccessPolicy ResourceRef="EncryptionCert" PrincipalRef="Service1" ResourceType="Certificate" />
		<SecurityAccessPolicy ResourceRef="WebAdminCert" PrincipalRef="Service1" ResourceType="Certificate" />
	</SecurityAccessPolicies>
</Policies>
	<Certificates>
		<SecretsCertificate X509FindValue="[EncryptionThumbprint]" Name="EncryptionCert" />
		<EndpointCertificate X509FindValue="[ApplicationClientThumbprint]" Name="WebAdminCert" />
	</Certificates>
</ApplicationManifest>
