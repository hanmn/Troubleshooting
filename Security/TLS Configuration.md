# TLS Configuration

## How to configure Service Fabric or Applications to use a specific TLS version

- Option 1 - Machine wide configuration
    Set HKEY\_LOCAL\_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319 \\SchUseStrongCrypto to true/1 this will force System.Net to use TLS 1.2 and disable Md5, RC4, 3DES cipher algorithm as those ciphers were considered as weak cipher.

- Option 2 - Application level configuration
    - Update yourapp.exe.config, for example FabricUS.exe.config if the process is using .Net Framework 4.6 and above
        - DontEnableSchUseStrongCrypto is mapping to "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319\\SchUseStrongCrypto" at per application through the app.config file.

```xml
    <?xml version="1.0" encoding="utf-8"?>
        <configuration>
            <runtime>
                <AppContextSwitchOverrides value=\"Switch.System.Net.DontEnableSchUseStrongCrypto=false\"/>
            <runtime>
        <configuration>
```
- Option 3 - Application level configuration by EXE, if you precisely know where .NET .exe located, like this:

```
    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\System.Net.ServicePointManager.SecurityProtocol
    Create REG_SZ string with content
    Name: D:\SvcFab\_App\__FabricSystem_App4294967295\US.Code.Current\FabricUS.exe
    Value: Tls12
```

- Valid values are Tls12, Tls11, Tls and Ssl3. Any combination of these values separated by a comma is acceptable.
- Invalid values will be silently treated as if the key is not present: default values will be used instead

## **Reference**

<https://docs.microsoft.com/en-us/dotnet/framework/configure-apps/file-schema/runtime/appcontextswitchoverrides-element>

search DontEnableSchUseStrongCrypto