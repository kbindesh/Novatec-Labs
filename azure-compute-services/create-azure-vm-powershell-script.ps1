# Description: This PowerShell script can used to provision Azure VM with new VNet, PublicIp, NSG
# Developer : K Bindesh  
# Reference links : 
# https://docs.microsoft.com/en-us/powershell/module/az.compute/set-azvmosdisk?view=azps-7.2.0
# https://docs.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-7.2.0


$resourceGoupName = 'novateclabsRG'
$azureRegion = 'East US'
$vmName = 'DemoPSVM'

# Create the resource group
New-AzResourceGroup -Name $resourceGoupName -Location $azureRegion -Verbose

# Create the vNet for the VM
$newSubnetParams = @{
    'Name'          = 'MySubnet'
    'AddressPrefix' = '10.0.1.0/24'
}
$subnet = New-AzVirtualNetworkSubnetConfig @newSubnetParams

$newVNetParams = @{
    'Name'              = 'MyNetwork'
    'ResourceGroupName' = $resourceGoupName
    'Location'          = $azureRegion
    'AddressPrefix'     = '10.0.0.0/16'
}
$vNet = New-AzVirtualNetwork @newVNetParams -Subnet $subnet -Verbose

# Create the storage account
$newStorageAcctParams = @{
    'Name'              = 'novatecdemolabsa' ## Must be globally unique and all lowercase
    'ResourceGroupName' = $resourceGoupName
    'Type'              = 'Standard_LRS'
    'Location'          = $azureRegion
}
$storageAccount = New-AzStorageAccount @newStorageAcctParams -Verbose

# Create the public IP address
$newPublicIpParams = @{
    'Name'              = 'MyPublicIP'
    'ResourceGroupName' = $resourceGoupName
    'AllocationMethod'  = 'Static' 			## Dynamic or Static
	'Zone'				= 1,2,3
    'Location'          = $azureRegion
	'Sku'				= 'Standard'
}
$publicIp = New-AzPublicIpAddress @newPublicIpParams -Verbose

# Create the vNic and assign to the soon-to-be created VM
$newVNicParams = @{
    'Name'              = 'MyNic'
    'ResourceGroupName' = $resourceGoupName
    'Location'          = $azureRegion
}
$vNic = New-AzNetworkInterface @newVNicParams -SubnetId $vNet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -Verbose


# Config the OS settings
$newConfigParams = @{
    'VMName' = $vmName
    'VMSize' = 'Standard_B2s'
}
$vmConfig = New-AzVMConfig @newConfigParams

$newVmOsParams = @{
    'Windows'          = $true
    'ComputerName'     = $vmName
    'Credential'       = (Get-Credential -Message 'Type the name and password of the local administrator account.')
    'ProvisionVMAgent' = $true
    'EnableAutoUpdate' = $true
}
$vm = Set-AzVMOperatingSystem @newVmOsParams -VM $vmConfig


# Define the OS disk image

# Find the OS offer
# $offer = Get-AzVMImageOffer -Location eastus -PublisherName MicrosoftWindowsServer | where { $_.Offer -eq 'WindowsServer' }

# Find the OS Sku
# Get-AzVMImageSku -Location 'east us' -PublisherName 'MIcrosoftWindowsServer' -Offer WindowsServer

$newSourceImageParams = @{
    'PublisherName' = 'MicrosoftWindowsServer'
    'Version'       = 'latest'
    'Skus'          = '2019-Datacenter'
}
 
$vm = Set-AzVMSourceImage @newSourceImageParams -VM $vm -Offer 'WindowsServer'


#Add the vNic created earlier
$vm = Add-AzVMNetworkInterface -VM $vm -Id $vNic.Id -Verbose


#Create the OS disk
$osDiskName = 'myDisk'
$osDiskUri = $storageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $osDiskName + ".vhd"
 
$newOsDiskParams = @{
    'Name'         = 'OSDisk'
    'CreateOption' = 'fromImage'
	#DiskSizeInGB  = 200 
}
 
$vm = Set-AzVMOSDisk @newOsDiskParams -VM $vm -VhdUri $osDiskUri


#Bring all of the work together to create the $vm variable and create the VM
New-AzVM -VM $vm -ResourceGroupName $resourceGoupName -Location $azureRegion -Verbose

#Stop the VM to save billing
Stop-AzVM -ResourceGroupName $resourceGoupName -Name $vmName

#Delete the resource group and its associated resources
Remove-AzResourceGroup -Name $resourceGoupName -Force
