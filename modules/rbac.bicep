// ============ //
// Parameters   //
// ============ //

@description('Required. Array of role assignments to create.')
param roleAssignments roleAssignmentType[]

// ============ //
// Resources    //
// ============ //

// RBAC scoped to Resource Group per design requirements
// No VM resource reference needed as assignments are at RG scope

// Deploy role assignments scoped to Resource Group (not VM directly)
// Per prompt requirement: RBAC scoped to ResourceGroup
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.authorization/roleassignments
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in roleAssignments: {
  name: guid(resourceGroup().id, assignment.principalId, assignment.roleDefinitionIdOrName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleDefinitionIdOrName)
    principalId: assignment.principalId
    principalType: assignment.?principalType ?? 'ServicePrincipal'
  }
}]

// ============ //
// Outputs      //
// ============ //

@description('The resource IDs of the role assignments.')
output resourceIds array = [for (assignment, i) in roleAssignments: roleAssignment[i].id]

@description('The names of the role assignments.')
output names array = [for (assignment, i) in roleAssignments: roleAssignment[i].name]

// ============== //
// Type Definitions //
// ============== //

@description('Role assignment configuration.')
type roleAssignmentType = {
  @description('The principal ID (object ID) of the identity to assign the role to.')
  principalId: string

  @description('The role definition ID or built-in role name to assign.')
  roleDefinitionIdOrName: string

  @description('The type of principal.')
  principalType: ('ServicePrincipal' | 'Group' | 'User' | 'ManagedIdentity')?
}
