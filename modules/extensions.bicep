// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the Virtual Machine.')
param vmName string

@description('Optional. Azure region for deployment.')
param location string = resourceGroup().location

@description('Required. The type of OS for the VM.')
@allowed([
  'Windows'
  'Linux'
])
param osType string

@description('Optional. Enable domain join extension.')
param enableDomainJoin bool = false

@description('Optional. Domain to join.')
param domainToJoin string = ''

@description('Optional. Domain join OU path.')
param ouPath string = ''

@description('Optional. Domain join username.')
param domainUsername string = ''

@description('Optional. Domain join password.')
@secure()
param domainPassword string = ''

@description('Optional. Enable custom script extension.')
param enableCustomScript bool = false

@description('Optional. Custom script URI.')
param customScriptUri string = ''

@description('Optional. Custom script command to execute.')
param customScriptCommand string = ''

@description('Required. Resource tags.')
param tags object

// ============ //
// Resources    //
// ============ //

// Reference existing Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: vmName
}

// Domain Join Extension (Windows only)
// MSLearn: https://learn.microsoft.com/azure/active-directory-domain-services/join-windows-vm
resource domainJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = if (enableDomainJoin && osType == 'Windows') {
  parent: virtualMachine
  name: 'JoinDomain'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: domainToJoin
      OUPath: ouPath
      User: domainUsername
      Restart: 'true'
      Options: '3' // Join domain and create computer account
    }
    protectedSettings: {
      Password: domainPassword
    }
  }
}

// Custom Script Extension (Windows)
resource customScriptWindows 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = if (enableCustomScript && osType == 'Windows') {
  parent: virtualMachine
  name: 'CustomScriptExtension'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: !empty(customScriptUri) ? [customScriptUri] : []
      commandToExecute: customScriptCommand
    }
  }
  dependsOn: [
    domainJoinExtension
  ]
}

// Custom Script Extension (Linux)
resource customScriptLinux 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = if (enableCustomScript && osType == 'Linux') {
  parent: virtualMachine
  name: 'CustomScript'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: !empty(customScriptUri) ? [customScriptUri] : []
      commandToExecute: customScriptCommand
    }
  }
}

// ============ //
// Outputs      //
// ============ //

@description('Domain join extension status.')
output domainJoinStatus string = enableDomainJoin && osType == 'Windows' ? (domainJoinExtension.?properties.?provisioningState ?? 'Unknown') : 'NotDeployed'

@description('Custom script extension status.')
output customScriptStatus string = enableCustomScript ? (osType == 'Windows' ? (customScriptWindows.?properties.?provisioningState ?? 'Unknown') : (customScriptLinux.?properties.?provisioningState ?? 'Unknown')) : 'NotDeployed'
