// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the Virtual Machine to configure diagnostics for.')
param vmName string

@description('Required. Resource ID of the Log Analytics workspace.')
param workspaceId string

@description('Optional. The name of the diagnostic setting.')
param diagnosticSettingName string = '${vmName}-diagnostics'

@description('Optional. Enable metrics collection.')
param enableMetrics bool = true

// ============ //
// Variables    //
// ============ //

// Metrics configuration for VMs
var metricsConfig = [
  {
    category: 'AllMetrics'
    enabled: enableMetrics
    retentionPolicy: {
      enabled: false
      days: 0
    }
  }
]

// ============ //
// Resources    //
// ============ //

// Reference existing Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: vmName
}

// Deploy diagnostic settings for Virtual Machine
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingName
  scope: virtualMachine
  properties: {
    workspaceId: workspaceId
    metrics: metricsConfig
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the diagnostic setting.')
output resourceId string = diagnosticSettings.id

@description('The name of the diagnostic setting.')
output name string = diagnosticSettings.name
