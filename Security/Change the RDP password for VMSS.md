## Change the RDP password for your nodetype (VMSS)

Here is a simple PowerShell script. 

```PowerShell
    $vmssName = "yourVmssName"
    $vmssResourceGroup = "yourVmssResourceGroupName"
    $publicConfig = @{"UserName" = "yourAdminUserName"}
    $privateConfig = @{"Password" = "***********"}

    $extName = "VMAccessAgent"
    $publisher = "Microsoft.Compute"
    Login-AzureRmAccount

    $vmss = Get-AzureRmVmss -ResourceGroupName $vmssResourceGroup -VMScaleSetName $vmssName

    $vmss = Add-AzureRmVmssExtension -VirtualMachineScaleSet $vmss -Name $extName -Publisher $publisher -Setting $publicConfig -ProtectedSetting $privateConfig -Type $extName -TypeHandlerVersion "2.0" -AutoUpgradeMinorVersion $true

    Update-AzureRmVmss -ResourceGroupName $vmssResourceGroup -Name $vmssName -VirtualMachineScaleSet $vmss
```

