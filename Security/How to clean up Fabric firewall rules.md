# How to clean up Fabric firewall rules

## **Steps**

1.  Open Registry

```cmd
    regedit
```

2. Export current firewall rules into file from below path. name file as firewallrules.reg

```regedit
    HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\SharedAccess\\Parameters\\FirewallPolicy\\FirewallRules
```

3. Extract Fabric firewall rules

```cmd
    type firewallrules.reg \| findstr /V Fabric \> newfirewallrules.reg
```

4. Open Registry and import filtered firewall rules back

    - Regedit
    - Rename current firewall reg key as firewallrulesold
    - import the newfirewallrules.reg file

5. Restart windows firewall

    - Open powershell in administrator mode


```PowerShell
    restart-service MpsSvc
```

- In case reboot required run following command ( killing lsass windows will kill all the process and will perform shutdown , use only when shutdown request is not going through)

```PowerShell
    taskkill /f /im lsass.exe & shutdown /r /t 1
```
 
6. Check number of rules

```PowerShell
    (Get-NetFirewallRule).count  
```
 

 

 
