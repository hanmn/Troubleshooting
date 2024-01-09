# Collecting logs for failed VMs

## Symptoms

VMs in VMSS are in Failed(Running) state in Azure Portal and preventing Service Fabric nodes from becoming healthy. In this state the VMs themselves are running but there is an error in one of the VMSS extensions. VMs will be accessible through RDP.

## Cause

There can be a number of reasons for a VMSS extension to fail

- Incorrect configuration
- A resource referenced by the VMSS extension is not available
- Timeouts or transient issues causing the extensions to fail

## Gathering more informaiton

1. RDP to one or more of the VMs in Failed state
2. Open command prompt and then run the following commands

    ```powershell
    md C:\guestlogs
    cd C:\guestlogs
    C:\WindowsAzure\GuestAgent_VERSION\CollectGuestLogs.exe (VERSION will be different values, use the highest version value)
    ```

3. This will create a compressed file with various logs
4. Copy the file out of the VM

## Mitigation

### Config issues

- Check failures in the logs to eliminate any config issues
  - For example, a reference to a resource could be wrong or no longer valid
- Fix the config issue in the ARM template and redeploy it

### Other issues

- Open Support Incident through the Azure Portal
- Include the logs collected from the VM(s) or the error message found in the logs
