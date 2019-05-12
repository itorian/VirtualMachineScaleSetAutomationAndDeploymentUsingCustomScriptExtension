## This script will create vmss infrastructure and add a custom script extension having web server setup and a MVC app to deploy

# Connect
Connect-AzureRmAccount

# Variables
$location = "EastUS"
$resourcegroup = "demo-vmss"
$vmssname = "vmss1"

# Create resource group
New-AzureRmResourceGroup `
  -ResourceGroupName $resourcegroup `
  -Location $location

# Create a config object
$vmssConfig = New-AzureRmVmssConfig `
  -Location $location `
  -SkuCapacity 2 `
  -SkuName Standard_DS2 `
  -UpgradePolicyMode Automatic

# Define the script for your Custom Script Extension to run on vmss
$settings = @{
  "fileUris" = (,"https://storageitorian.blob.core.windows.net/setup-infra-and-deploy-app/create-webserver-and-deploy-app.ps1");
  "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File create-webserver-and-deploy-app.ps1"
}

# Use Custom Script Extension to install IIS and configure mvc/asp.net website
$extensionname = "CustomScript"
Add-AzureRmVmssExtension `
  -VirtualMachineScaleSet $vmssConfig `
  -Name $extensionname `
  -Publisher "Microsoft.Compute" `
  -Type "CustomScriptExtension" `
  -TypeHandlerVersion 1.8 `
  -Setting $settings

# Create a public IP address
$publicIP = New-AzureRmPublicIpAddress `
  -ResourceGroupName $resourcegroup `
  -Location $location `
  -AllocationMethod Static `
  -Name myPublicIP

# Create a frontend and backend IP pool
$frontendIP = New-AzureRmLoadBalancerFrontendIpConfig `
  -Name myFrontEndPool `
  -PublicIpAddress $publicIP
$backendPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name myBackEndPool

# Create the load balancer
$lb = New-AzureRmLoadBalancer `
  -ResourceGroupName $resourcegroup `
  -Name myLoadBalancer `
  -Location $location `
  -FrontendIpConfiguration $frontendIP `
  -BackendAddressPool $backendPool

# Create a load balancer health probe on port 80
Add-AzureRmLoadBalancerProbeConfig -Name myHealthProbe `
  -LoadBalancer $lb `
  -Protocol tcp `
  -Port 80 `
  -IntervalInSeconds 15 `
  -ProbeCount 2

# Create a load balancer rule to distribute traffic on port 80
Add-AzureRmLoadBalancerRuleConfig `
  -Name myLoadBalancerRule `
  -LoadBalancer $lb `
  -FrontendIpConfiguration $lb.FrontendIpConfigurations[0] `
  -BackendAddressPool $lb.BackendAddressPools[0] `
  -Protocol Tcp `
  -FrontendPort 80 `
  -BackendPort 80

# Update the load balancer configuration
Set-AzureRmLoadBalancer -LoadBalancer $lb

# Reference a virtual machine image from the gallery
Set-AzureRmVmssStorageProfile $vmssConfig `
  -ImageReferencePublisher MicrosoftWindowsServer `
  -ImageReferenceOffer WindowsServer `
  -ImageReferenceSku 2016-Datacenter `
  -ImageReferenceVersion latest `
  -OsDiskCreateOption FromImage

# Set up information for authenticating with the virtual machine
Set-AzureRmVmssOsProfile $vmssConfig `
  -AdminUsername azureuser `
  -AdminPassword P@ssword! `
  -ComputerNamePrefix myVM

# Create the virtual network resources
$subnet = New-AzureRmVirtualNetworkSubnetConfig `
  -Name "mySubnet" `
  -AddressPrefix 10.0.0.0/24
$vnet = New-AzureRmVirtualNetwork `
  -ResourceGroupName $resourcegroup `
  -Name "myVnet" `
  -Location $location `
  -AddressPrefix 10.0.0.0/16 `
  -Subnet $subnet
$ipConfig = New-AzureRmVmssIpConfig `
  -Name "myIPConfig" `
  -LoadBalancerBackendAddressPoolsId $lb.BackendAddressPools[0].Id `
  -SubnetId $vnet.Subnets[0].Id

# Attach the virtual network to the config object
Add-AzureRmVmssNetworkInterfaceConfiguration `
  -VirtualMachineScaleSet $vmssConfig `
  -Name "network-config" `
  -Primary $true `
  -IPConfiguration $ipConfig

# Create the scale set with the config object (this step might take a few minutes)
New-AzureRmVmss `
  -ResourceGroupName $resourcegroup `
  -Name $vmssname `
  -VirtualMachineScaleSet $vmssConfig

# Get ip
Get-AzureRmPublicIPAddress `
  -ResourceGroupName $resourcegroup `
  -Name myPublicIP | select IpAddress