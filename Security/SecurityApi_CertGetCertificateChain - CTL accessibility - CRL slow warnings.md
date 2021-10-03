## How to mitigate SecurityApi_CertGetCertificateChain health warning (CTL accessibility issue or CRL slow/offline)

## Assessment
You can modify the threshold to mitigate such warnings about slow certificate chain validations or CRL lookup by setting SlowAPiThreshold value.  However, while removing the warnings from SFX the performance issue may still persist.

```json
{
  "name": "Security",
  "parameters": [
    {
      "name": "SlowApiThreshold ",
      "value": "some larger value"
    }
  ]
}
```

Reference: [Modify configuration setting for Security/SlowApiThreshold](https://github.com/Microsoft/service-fabric/issues/48)

This warning may also be caused when a NSG has blocked certificate CRL and CTL access/download.

## Mitigation
  * If the machine does not have access to public Internet access, then the slowdown is most probably caused by downloading Windows CTL and disallowed certificates, add the following to fabricSettings (FabricSettings in cluster manifest xml) and do a configuration upgrade. If Security or Federation section already exists, then add the settings to the existing section instead of creating a new one.

  * JSON changes:
```json
    {
      "name": "Security",
      "parameters": [
        {
          "name": "CrlCheckingFlag",
          "value": "4"
        }
      ]
    }, 
    {
      "name": "Federation",
      "parameters": [
        {
          "name": "X509CertChainFlags",
          "value": "4"
        }
      ]
    }
```

* ClusterManifest changes for customers that still use cluster manifest:

```xml
  <FabricSettings>
    <Section Name="Security">
      <Parameter Name="CrlCheckingFlag" Value="4"/>
    </Section>
    <Section Name="Federation">
      <Parameter Name="X509CertChainFlags" Value="4" />
    </Section>
```

* If the above does not solve the issue, CRL downloading should be checked, if CRL downloading is the issue, add the following to disable CRL downloading:
  JSON changes:

```json
  {
    "name": "Security",
      "parameters": [
      {
        "name": "CrlCheckingFlag",
        "value": "0x80000000"
      }
    ]
  },
  {
    "name": "Federation",
    "parameters": [
      {
        "name": "X509CertChainFlags",
        "value": "0x80000000"
      }
    ]
  }
```

* ClusterManifest changes for customers that still use cluster manifest:

```xml
  <FabricSettings>
    <Section Name="Security">
      <Parameter Name="CrlCheckingFlag" Value="0x80000000"/>
    </Section>
    <Section Name="Federation">
      <Parameter Name="X509CertChainFlags" Value="0x80000000" />
    </Section>
```

* If both CTL and CRL downloading are slow or unavailable, then we need make the above config change with flag value set to 0x80000004 (OR of 4 and 0x80000000)
