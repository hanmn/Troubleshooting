# DigiCert-issued cluster certificates declared by Common Name with issuer pinning may fail due to key confusion

[Issue](#Issue)  
[Affects](#Affects)  
[Symptoms](#Symptoms)  
[Cause](#Cause)  
[Impact](#Impact)  
[Mitigation](#Mitigation)  
[Resolution](#Resolution)  

## Issue

Service Fabric clusters secured with DigiCert-issued certificates declared by Common Name with issuer thumbprint pinning are at risk of failing validation. This may lead to partial cluster unavailability, the cluster being inaccessible or cluster upgrades stalling/failing.

## Affects

This issue affects any cluster version with the following configuration:  

- Using DigiCert-issued X509 Certificates declared by common name with issuer pinning
- Cluster certificate is issued by either of the [DigiCert SHA2 Secure Server CA](https://www.digicert.com/kb/digicert-root-certificates.htm#intermediates); you can identify if this is the case as follows:
  - the cluster certificate's Authority Key Identifier (AKI, extension OId: 2.5.29.35) of 0f80611c823161d52f28e78d4638b42ce1c6d9e2, or
  - the signing certificate has the SHA-1 thumbprint 1fb86b1168ec743154062e8c9cc5b171a4b7ccb4 or 626d44e704d1ceabe3bf0d53397464ac8080142c 
- The cluster certificate's issuer thumbprint list includes only one, but not both of the following SHA-1 thumbprints: 1fb86b1168ec743154062e8c9cc5b171a4b7ccb4, 626d44e704d1ceabe3bf0d53397464ac8080142c

## Symptoms

- One or more cluster nodes appear down/unhealthy
- Cluster is unreachable, whether from the Azure portal or directly (SFX/other clients)
- Event logs show errors similar to: "authorization failure: CertificateNotMatched"
- Any pending upgrades are not progressing

Example event message from Application event log:

```xml
Log Name:      Application
Source:        ServiceFabricNodeBootstrapAgent
Date:          11/22/2020 14:34:51
Event ID:      0
Task Category: None
Level:         Warning
Keywords:      Classic
User:          N/A
Computer:      nt0000001
Description:
The operation completed successfully.
Event Xml:
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <System>
    <Provider Name="ServiceFabricNodeBootstrapAgent" />
    <EventID Qualifiers="0">0</EventID>
    <Level>3</Level>
    <Task>0</Task>
    <Keywords>0x80000000000000</Keywords>
    <TimeCreated SystemTime="2020-11-22T19:34:51.1949822Z" />
    <EventRecordID>1414648</EventRecordID>
    <Channel>Application</Channel>
    <Computer>nt0000001</Computer>
    <Security />
  </System>
  <EventData>
    <Data>Request failed: POST https://eastus.servicefabric.azure.com/runtime/clusters/c7c396d4-077e-42b0-b709-a2ef120132ad/nodes/_nt0_1/vmextensionRepair (CorrelationId=36967c8c-a63d-4067-8de5-597cc8a24e51,  UtcTime=11/22/2020 19:34:51, Certificate=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx)
{"sequenceNumber":"0","output":""}</Data>
  </EventData>
</Event>
```

Example event message from Microsoft-ServiceFabric/Admin event log:

```xml
Log Name:      Microsoft-ServiceFabric/Admin
Source:        Microsoft-ServiceFabric
Date:          11/22/2020 14:30:52
Event ID:      4173
Task Category: Transport
Level:         Warning
Keywords:      Default
User:          NETWORK SERVICE
Computer:      nt0000001
Description:
authorization failure: CertificateNotMatched
Event Xml:
<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event">
  <System>
    <Provider Name="Microsoft-ServiceFabric" Guid="{cbd93bc2-71e5-4566-b3a7-595d8eeca6e8}" />
    <EventID>4173</EventID>
    <Version>2</Version>
    <Level>3</Level>
    <Task>16</Task>
    <Opcode>0</Opcode>
    <Keywords>0x8000000000000001</Keywords>
    <TimeCreated SystemTime="2020-11-22T19:30:52.3311685Z" />
    <EventRecordID>3087928</EventRecordID>
    <Correlation />
    <Execution ProcessID="15852" ThreadID="13412" />
    <Channel>Microsoft-ServiceFabric/Admin</Channel>
    <Computer>nt0000001</Computer>
    <Security UserID="S-1-5-20" />
  </System>
  <EventData>
    <Data Name="id">2173b6ea5d0</Data>
    <Data Name="error">2147949758</Data>
  </EventData>
</Event>
```

## Cause

DigiCert introduced a new CA which reuses the signing key of an existing and still-valid CA. This means there are 2 different CA certificates in circulation, and either can be included in the chain built for a certificate signed by this shared key. Existing certificates declared in SF clusters by subject with issuer pinning are at risk of spontaneously failing validation. This PKI/set of CAs is not restricted to a given cloud.

- SHA-1 Thumbprint of new CA: 1fb86b1168ec743154062e8c9cc5b171a4b7ccb4
- SHA-1 Thumprint of Existing CA: 626d44e704d1ceabe3bf0d53397464ac8080142c

Since the two CA certificates are using the same signing key, either can be resolved as the intermediate upon building the certificate chain of the cluster certificate; if the declaration specifies only one of the issuer thumbprints, and the actual chain includes the other one, validation will fail. As a consequence, in-cluster or cluster-to-RP calls will fail with an authentication error. On Windows, CryptoAPI will favor the most recently issued CA certificates from multiple matches; given that this CA was recently introduced, its thumbprint will not be listed on the cluster certificate declaration, and so the likelihood of failure is high.

## Mitigation
Action is needed for clusters which meet the description in the Affects section, whether or not the symptoms have been observed, as follows:

If the cluster does not show the symptoms: pease run a cluster upgrade as soon as possible to add the new certificate issuer thumbprint: 

"1fb86b1168ec743154062e8c9cc5b171a4b7ccb4" -> "1fb86b1168ec743154062e8c9cc5b171a4b7ccb4,626d44e704d1ceabe3bf0d53397464ac8080142c" (and including any other pre-existing TPs)

If an upgrade is unfeasible or the cluster is already affected:

On each node in the cluster,
- Install the CA cert with Thumbprint 626d44e704d1ceabe3bf0d53397464ac8080142c in the LocalMachine\Disallowed store in certlm.msc, "Local Computer\Untrusted certificates"  
- Issuer/ Intermediate certficate 626d44e704d1ceabe3bf0d53397464ac8080142c can be downloaded from https://www.digicert.com/kb/digicert-root-certificates.htm#intermediates

example command once .crt file has been downloaded:  

```cmd
certutil -addstore -enterprise Disallowed .\DigiCertSHA2SecureServerCA-2.crt
```

Once this is done, cluster should restore. If it does not, please look for the following symptoms: 
- Calls are failing with FABRIC_E_GATEWAY_NOT_REACHABLE

If these symptoms are present, a rolling restart will need to take place. 

On each seed node, one-by-one, either
- Restart each of the seed nodes or
- On each seed node, terminate the following processes: FabricGateway.exe, FileStoreService.exe, FabricUpgrade.exe

Please wait for FabricGateway.exe to come up on each node before proceeding to the next node. This will help prevent further availability loss.

## Resolution

Update cluster definitions to include the new issuer thumbprint as soon as possible. If the cluster is not yet affected or has already been mitigated, start a cluster upgrade as soon as feasible to include 626d44e704d1ceabe3bf0d53397464ac8080142c in the certificateIssuerThumbprint list.  
