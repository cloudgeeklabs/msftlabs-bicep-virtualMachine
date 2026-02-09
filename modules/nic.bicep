// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the Network Interface.')
param nicName string

@description('Optional. Azure region for deployment.')
param location string = resourceGroup().location

@description('Required. The resource ID of the subnet.')
param subnetId string

@description('Optional. Enable accelerated networking.')
param enableAcceleratedNetworking bool = true

@description('Optional. Public IP resource ID to associate. Empty string means no public IP.')
param publicIpId string = ''

@description('Optional. Network Security Group resource ID to associate.')
param networkSecurityGroupId string = ''

@description('Optional. IP configuration name.')
param ipConfigurationName string = 'ipconfig1'

@description('Optional. Private IP allocation method.')
@allowed([
  'Dynamic'
  'Static'
])
param privateIPAllocationMethod string = 'Dynamic'

@description('Optional. Static private IP address. Only used when privateIPAllocationMethod is Static.')
param privateIPAddress string = ''

@description('Required. Resource tags.')
param tags object

// ============ //
// Variables    //
// ============ //

// Build IP configuration
var ipConfiguration = {
  name: ipConfigurationName
  properties: union(
    {
      subnet: {
        id: subnetId
      }
      privateIPAllocationMethod: privateIPAllocationMethod
    },
    !empty(publicIpId) ? {
      publicIPAddress: {
        id: publicIpId
      }
    } : {},
    privateIPAllocationMethod == 'Static' && !empty(privateIPAddress) ? {
      privateIPAddress: privateIPAddress
    } : {}
  )
}

// ============ //
// Resources    //
// ============ //

// Deploy Network Interface
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.network/networkinterfaces
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      ipConfiguration
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
    networkSecurityGroup: !empty(networkSecurityGroupId) ? {
      id: networkSecurityGroupId
    } : null
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the NIC.')
output resourceId string = nic.id

@description('The name of the NIC.')
output name string = nic.name

@description('The private IP address of the NIC.')
output privateIPAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
