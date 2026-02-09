// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the Public IP.')
param publicIpName string

@description('Optional. Azure region for deployment.')
param location string = resourceGroup().location

@description('Optional. SKU for the Public IP.')
@allowed([
  'Basic'
  'Standard'
])
param sku string = 'Standard'

@description('Optional. Allocation method for the Public IP.')
@allowed([
  'Dynamic'
  'Static'
])
param allocationMethod string = 'Static'

@description('Optional. Availability zone for the Public IP.')
param zones array = []

@description('Required. Resource tags.')
param tags object

// ============ //
// Resources    //
// ============ //

// Deploy Public IP Address
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.network/publicipaddresses
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: sku
    tier: 'Regional'
  }
  zones: !empty(zones) ? zones : null
  properties: {
    publicIPAllocationMethod: allocationMethod
    publicIPAddressVersion: 'IPv4'
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Public IP.')
output resourceId string = publicIp.id

@description('The name of the Public IP.')
output name string = publicIp.name

@description('The IP address.')
output ipAddress string = publicIp.properties.?ipAddress ?? ''
