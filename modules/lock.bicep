// ============ //
// Parameters   //
// ============ //

@description('Required. The name of the Virtual Machine to lock.')
param vmName string

@description('Optional. The lock level to apply.')
@allowed([
  'CanNotDelete'
  'ReadOnly'
])
param lockLevel string = 'CanNotDelete'

@description('Optional. Notes describing why the lock was applied.')
param lockNotes string = 'Prevents accidental deletion of production Virtual Machine.'

// ============ //
// Resources    //
// ============ //

// Reference existing Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' existing = {
  name: vmName
}

// Apply resource lock to Virtual Machine
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.authorization/locks
resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${vmName}-lock'
  scope: virtualMachine
  properties: {
    level: lockLevel
    notes: lockNotes
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the lock.')
output resourceId string = lock.id

@description('The name of the lock.')
output name string = lock.name

@description('The lock level applied.')
output level string = lock.properties.level
