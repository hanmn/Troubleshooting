# TLS Configuration

## How to configure Service Fabric or Applications to use a specific TLS version

- Option 1 - Machine wide configuration
    Set HKEY\_LOCAL\_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319 \\SchUseStrongCrypto to true/1 will force [System.Net](https://docs.microsoft.com/en-us/dotnet/api/system.net?view=netframework-4.7.2) **CLIENT** to use TLS 1.2 and disable Md5, RC4, 3DES cipher algorithm as those ciphers were considered as week cipher. 

- Option 2 - Application level configuration
    - Update yourapp.exe.config, for example FabricUS.exe.config if the process is using .Net Framework 4.6 and above
        - DontEnableSchUseStrongCrypto is mapping to "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319\\SchUseStrongCrypto" at per application through the app.config file.
            - <https://docs.microsoft.com/en-us/dotnet/framework/configure-apps/file-schema/runtime/appcontextswitchoverrides-element>
            - search DontEnableSchUseStrongCrypto

```xml
    <?xml version="1.0" encoding="utf-8"?>
        <configuration>
            <runtime>
                <AppContextSwitchOverrides value=\"Switch.System.Net.DontEnableSchUseStrongCrypto=false\"/>
            <runtime>
        <configuration>
```

- Option 3 - Application level configuration by EXE, if you precisely know where the .NET .exe is located, like this:
    - Valid values are Tls12, Tls11, Tls and Ssl3. Any combination of these values separated by a comma is acceptable.
    - Invalid values will be silently treated as if the key is not present: default values will be used instead

```
    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\System.Net.ServicePointManager.SecurityProtocol
    Create REG_SZ string with content
    Name: D:\SvcFab\_App\__FabricSystem_App4294967295\US.Code.Current\FabricUS.exe
    Value: Tls12
```

This TSG is primarily discussing SSL/TLS client behavior such as FabricUS.exe. For additional reference, you may check:
At Crypto API/schannel level for entire windows machine, <https://support.microsoft.com/en-us/help/245030/how-to-restrict-the-use-of-certain-cryptographic-algorithms-and-protoc> as this reference covers both client and server side.

If you are **not** looking for schannel driver level security hardening,  but rather want to do it from the .Net Framework level, you can check these MSDN references:
- <https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls>
- <https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/mitigation-tls-protocols>

## **Note :**
Service Fabric Upgrade Service (FabricUS.exe) currently depends on TLS 1.0, but please note that this is not a limitation of FabricUS.exe, however it is the DotNet Framework that defaults to TLS 1.0.  Recently we have noticed that customers are blocking the TLS 1.0 channel for security compliance reasons.  When this is done on a Service Fabric Cluster the FabricUS.exe (fabric:/system/UpgradeService) won't be able to communicate with the Service Fabric Resource Provider (SFRP), which will cause the following symptoms:

1. Cluster will be showing **UpgradeServiceNotReachable** status
2. Azure Portal cannot display the node and application status.

So  if you want to force FabricUS.exe to leverage TLS 1.2 protocol, please tweak the registry key as suggested in Option:2 or 3, so that the DotNet Framework will default to TLS 1.2.


# Linux Clusters

Update the cluster settings in Security section - EnforceLinuxMinTlsVersion and TLS1_2_CipherList as needed

- EnforceLinuxMinTlsVersion	bool, default is FALSE
  - set to true; only TLS version 1.2+ is supported. If false; support earlier TLS versions. Applies to Linux only

This setting should enforce TLS1.2 for Service Fabric's Transport and HTTP Gateway. It’s not a machine-wide setting. For more information on setting up machine level TLS setting, please contact Ubuntu support - https://ubuntu.com/support

 **more info**
- https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-fabric-settings#security
