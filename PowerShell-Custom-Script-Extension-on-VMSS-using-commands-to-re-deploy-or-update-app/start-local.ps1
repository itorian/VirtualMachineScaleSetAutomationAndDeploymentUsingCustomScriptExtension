## This script will remove existing vmss custom script extension and add a new custom script extension updated MVC app to redeploy

# Connect
Connect-AzureRmAccount

# Variables
$resourcegroup = "demo-vmss"
$vmssname = "vmss1"

# Define the script for your Custom Script Extension to run on vmss
$publicSettings = @{
  "fileUris" = (,"https://storageitorian.blob.core.windows.net/re-deploy-app/re-deploy-app.ps1");
  "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File re-deploy-app.ps1"
}

# Get vmss
$vmss = Get-AzureRmVmss -ResourceGroupName $resourcegroup -VMScaleSetName $vmssname

# Remove extension
$extensionname = "CustomScript"
Remove-AzureRmVmssExtension -VirtualMachineScaleSet $vmss -Name $extensionname
Update-AzureRmVmss -ResourceGroupName $resourcegroup -Name $vmssname -VirtualMachineScaleSet $vmss

# Use Custom Script Extension to deploy mvc/asp.net website
Add-AzureRmVmssExtension `
  -VirtualMachineScaleSet $vmss `
  -Name $extensionname `
  -Publisher "Microsoft.Compute" `
  -Type "CustomScriptExtension" `
  -TypeHandlerVersion 1.8 `
  -Setting $publicSettings

# Update the VMSS model
Update-AzureRmVmss -ResourceGroupName $resourcegroup -Name $vmssname -VirtualMachineScaleSet $vmss