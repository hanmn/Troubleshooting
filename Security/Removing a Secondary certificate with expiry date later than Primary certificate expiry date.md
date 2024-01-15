# Removing a Secondary certificate with expiry date later than Primary certificate expiry date

*NOTE*: This article applies to ARM/Portal deployed environments and does not apply to other environments.

There may be situations where it is necessary to remove the secondary certificate (or even the primary), and which is valid longer than the remaining certificate. SF will by default pick the longest valid certificate of all existing matches. The normal procedure to remove the Secondary certificate will not work in this situation.

## Prerequisite

1. Cluster is deployed through ARM or Azure Portal

2. ARM template is available for ARM deployed clusters

3. For portal deployed clusters, access is available to the configuration for the cluster through [resources.azure.com](https://resources.azure.com)

4. Certificate is provisioned on the VMs through OsProfile.Secrets in VMSS configuration

5. Primary certificate is not expired and is valid for at least 15-30 days

6. Primary certificate is installed on every node of the cluster

**DO NOT** proceed with the steps if any of the above prerequisites is not met.

## Tasks to remove the secondary certificate

**NOTE:** Following assumes ARM template. When using [resources.azure.com](https://resources.azure.com), make the changes in the corresponding sections of the resource configurations.

**DO NOT** take these steps if the primary certificate is expired, or if it is not installed on every node of the cluster.

"_Certificate_" in rest of the steps below refers to the certificate the is being removed.

### Remove provisioning of certificate on VMs

1. Find and remove all references to the certificate in each of the VMSS resource deployed through the ARM template

    a. **WARNING**: At this point, do not make any change related to the certificate in  descriptions for other resource types in the ARM template.

2. Deploy the ARM template with the change

3. Wait for the update to complete

### Make sure that SF has stopped using the removed certificate

Following steps are required for any version up to and including 7.1.410.9590

1. In Azure portal, locate the VMSS associated with the cluster

2. Restart all instances of the VM one by one across all VMSS

3. Wait for VM to restart and become healthy in SF before restarting the next VM

4. If the VMSS and corresponding SF node have Silver or higher durability, then you can select all instances and issue the command to restart. Silver or higher durability ensures that VMs are restarted by Update Domain

5. Wait for all VMs to reboot and become healthy in SF

### Remove reference to certificate from Service Fabric resource description

1. In the ARM template locate and remove reference to the certificate

2. Deploy the ARM template

3. Once upgrade is complete for the cluster, SF cluster should no longer have a dependency on the certificate
