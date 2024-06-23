# Service Fabric Common Name Digicert Multiple Issuer Thumbprints

[Issue](#Issue)  
[Affects](#Affects)  
[Symptoms](#Symptoms)  
[Cause](#Cause)  
[Impact](#Impact)  
[Mitigation](#Mitigation)  
[Resolution](#Resolution)  

## Issue

Service Fabric clusters using Certificate Common Name and Issuer thumbprint 1fb86b1168ec743154062e8c9cc5b171a4b7ccb4 may become unresponsive or have state 'Upgrade Service Unreachable'.  

## Affects

This issue affects any cluster version that has the following configuration:  

- Certificate Common Name instead of thumbprint
- Certificate issued from Digicert
- Certificate Issuer Thumbprint configured with only: 1fb86b1168ec743154062e8c9cc5b171a4b7ccb4  

## Symptoms

- One or mode cluster nodes appear down/unhealthy
- Cluster is unreachable, whether from the Azure portal or directly (SFX/other clients)
- Event logs show errors similar to: "authorization failure: CertificateNotMatched"

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

## Impact

Issue can cause either one or more nodes to stop participating in cluster or for entire cluster to stop functioning.

## Mitigation

If an upgrade is unfeasible or the cluster is already affected:

- Install the CA cert with Thumbprint 626d44e704d1ceabe3bf0d53397464ac8080142c in the LocalMachine\Disallowed store in certlm.msc, "Local Computer\Untrusted certificates"  
- Issuer/ Intermediate certficate 626d44e704d1ceabe3bf0d53397464ac8080142c can be downloaded from https://www.digicert.com/kb/digicert-root-certificates.htm

example command once .crt file has been downloaded:  

```cmd
certutil -addstore -enterprise Disallowed .\DigiCertSHA2SecureServerCA-2.crt
```

or  

- If you have multiple certificates with the same CN from authorized issuers, fall back to one not signed by the shared key by deleting the conflicting certificate and let the cluster choose another certificate. This change however has risks and should be tested.

## Resolution

Update cluster definitions to include the new issuer thumbprint as soon as possible. If the cluster is not yet affected or has already been mitigated, start a cluster upgrade as soon as feasible to include 626d44e704d1ceabe3bf0d53397464ac8080142c in the certificateIssuerThumbprint list.  
