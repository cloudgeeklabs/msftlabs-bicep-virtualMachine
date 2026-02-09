metadata name = 'VirtualMachine Module'
metadata description = 'Deploys Azure Virtual Machine (Windows or Linux) with NICs, public IPs, extensions, and enterprise security defaults!'
metadata owner = 'cloudgeeklabs'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Workload name used to generate resource names. Max 10 characters, lowercase letters and numbers only.')
@minLength(2)
@maxLength(10)
param workloadName string

@description('Optional. Azure region for deployment. Defaults to resource group location.')
param location string = resourceGroup().location

@description('Optional. Environment identifier (dev, test, prod). Used in naming and tagging.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Required. The type of OS for the VM.')
@allowed([
  'Windows'
  'Linux'
])
param osType string

@description('Required. The size of the Virtual Machine.')
param vmSize string

@description('Required. Admin username for the VM.')
param adminUsername string

@description('Optional. Admin password for the VM. Required for Windows VMs.')
@secure()
param adminPassword string = ''

@description('Optional. SSH public key for Linux VMs.')
param sshPublicKey string = ''

@description('Required. Image reference for the VM OS disk.')
param imageReference imageReferenceType

@description('Optional. OS Disk configuration.')
param osDisk osDiskType = {
  createOption: 'FromImage'
  managedDisk: {
    storageAccountType: 'Premium_LRS'
  }
  caching: 'ReadWrite'
  diskSizeGB: 128
}

@description('Optional. Data disks to attach to the VM.')
param dataDisks dataDiskType[] = []

@description('Required. Network interface configurations. First NIC is primary.')
param nicConfigs nicConfigType[]

@description('Optional. Enable public IP for the primary NIC.')
param enablePublicIp bool = false

@description('Optional. Availability zone for the VM.')
param availabilityZone string = ''

@description('Optional. Enable domain join extension (Windows only).')
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

@description('Optional. Log Analytics workspace ID for diagnostics. Uses default if not specified.')
param diagnosticWorkspaceId string = ''

@description('Optional. Enable diagnostic settings.')
param enableDiagnostics bool = true

@description('Optional. Enable resource lock to prevent deletion.')
param enableLock bool = true

@description('Optional. Lock level to apply if enabled.')
@allowed([
  'CanNotDelete'
  'ReadOnly'
])
param lockLevel string = 'CanNotDelete'

@description('Optional. RBAC role assignments scoped to the resource group.')
param roleAssignments roleAssignmentType[] = []

@description('Required. Resource tags for organization and cost management.')
param tags object

// ============ //
// Variables    //
// ============ //

// Generate unique suffix using resource group ID to ensure uniqueness
var uniqueSuffix = take(uniqueString(resourceGroup().id, subscription().id), 5)

// Construct VM name
var vmName = 'vm-${toLower(workloadName)}-${environment}-${uniqueSuffix}'

// Default Log Analytics workspace for diagnostics if not provided
var defaultWorkspaceId = '/subscriptions/b18ea7d6-14b5-41f3-a00d-804a5180c589/resourceGroups/msft-core-observability/providers/Microsoft.OperationalInsights/workspaces/msft-core-cus-law'

// Merge provided workspace ID with default using conditional logic
var mergedWorkspaceId = !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : defaultWorkspaceId

// ============ //
// Resources    //
// ============ //

// Deploy Public IP if enabled (for primary NIC only)
module publicIp 'modules/publicIp.bicep' = if (enablePublicIp) {
  name: '${uniqueString(deployment().name, location)}-public-ip'
  params: {
    publicIpName: '${vmName}-pip'
    location: location
    sku: 'Standard'
    allocationMethod: 'Static'
    tags: tags
  }
}

// Deploy Network Interfaces
module nics 'modules/nic.bicep' = [for (nicConfig, i) in nicConfigs: {
  name: '${uniqueString(deployment().name, location)}-nic-${i}'
  params: {
    nicName:  nicConfig.?name ?? '${vmName}-nic-${i}'
    location: location
    subnetId: nicConfig.subnetId
    enableAcceleratedNetworking: nicConfig.?enableAcceleratedNetworking ?? true
    publicIpId: i == 0 && enablePublicIp ? (publicIp.?outputs.resourceId ?? '') : ''
    networkSecurityGroupId: nicConfig.?networkSecurityGroupId ?? ''
    privateIPAllocationMethod: nicConfig.?privateIPAllocationMethod ?? 'Dynamic'
    privateIPAddress: nicConfig.?privateIPAddress ?? ''
    tags: tags
  }
}]

// Deploy Virtual Machine
module virtualMachine 'modules/virtualMachine.bicep' = {
  name: '${uniqueString(deployment().name, location)}-virtual-machine'
  params: {
    vmName: vmName
    location: location
    osType: osType
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    sshPublicKey: sshPublicKey
    imageReference: imageReference
    osDisk: osDisk
    dataDisks: dataDisks
    networkInterfaceIds: [for (nicConfig, i) in nicConfigs: nics[i].outputs.resourceId]
    bootDiagnosticsStorageUri: ''
    availabilityZone: availabilityZone
    tags: tags
  }
}

// Deploy Extensions (domain join, custom script)
module extensions 'modules/extensions.bicep' = if (enableDomainJoin || enableCustomScript) {
  name: '${uniqueString(deployment().name, location)}-extensions'
  params: {
    vmName: virtualMachine.?outputs.name ?? ''
    location: location
    osType: osType
    enableDomainJoin: enableDomainJoin
    domainToJoin: domainToJoin
    ouPath: ouPath
    domainUsername: domainUsername
    domainPassword: domainPassword
    enableCustomScript: enableCustomScript
    customScriptUri: customScriptUri
    customScriptCommand: customScriptCommand
    tags: tags
  }
}

// Deploy Diagnostic Settings
module diagnostics 'modules/diagnostics.bicep' = if (enableDiagnostics) {
  name: '${uniqueString(deployment().name, location)}-diagnostics'
  params: {
    vmName: virtualMachine.?outputs.name ?? ''
    workspaceId: mergedWorkspaceId
    enableMetrics: true
  }
}

// Deploy Resource Lock to prevent accidental deletion
module lock 'modules/lock.bicep' = if (enableLock) {
  name: '${uniqueString(deployment().name, location)}-lock'
  params: {
    vmName: virtualMachine.?outputs.name ?? ''
    lockLevel: lockLevel
    lockNotes: 'Prevents accidental deletion of ${environment} VM for ${workloadName}'
  }
}

// Deploy RBAC Role Assignments (scoped to Resource Group)
module rbac 'modules/rbac.bicep' = if (!empty(roleAssignments)) {
  name: '${uniqueString(deployment().name, location)}-rbac'
  params: {
    roleAssignments: roleAssignments
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Virtual Machine.')
output resourceId string = virtualMachine.?outputs.resourceId ?? ''

@description('The name of the Virtual Machine.')
output name string = virtualMachine.?outputs.name ?? ''

@description('The resource group the VM was deployed into.')
output resourceGroupName string = virtualMachine.?outputs.resourceGroupName ?? ''

@description('The location the resource was deployed into.')
output location string = virtualMachine.?outputs.location ?? ''

@description('The generated VM name.')
output vmName string = vmName

@description('The NIC resource IDs.')
output nicResourceIds array = [for (nicConfig, i) in nicConfigs: nics[i].outputs.resourceId]

@description('The NIC private IP addresses.')
output nicPrivateIPs array = [for (nicConfig, i) in nicConfigs: nics[i].outputs.privateIPAddress]

@description('The public IP address (if enabled).')
output publicIpAddress string = enablePublicIp ? (publicIp.?outputs.ipAddress ?? '') : ''

@description('The environment identifier.')
output environment string = environment

@description('The unique naming suffix generated.')
output uniqueSuffix string = uniqueSuffix

// ============== //
// Type Definitions //
// ============== //

@description('Image reference type for VM OS.')
type imageReferenceType = {
  @description('The publisher of the image.')
  publisher: string

  @description('The offer of the image.')
  offer: string

  @description('The SKU of the image.')
  sku: string

  @description('The version of the image.')
  version: string
}

@description('OS Disk configuration type.')
type osDiskType = {
  @description('How the disk should be created.')
  createOption: ('FromImage' | 'Empty' | 'Attach')

  @description('Managed disk configuration.')
  managedDisk: {
    @description('Storage account type for the managed disk.')
    storageAccountType: ('Premium_LRS' | 'StandardSSD_LRS' | 'Standard_LRS' | 'Premium_ZRS' | 'StandardSSD_ZRS')
  }

  @description('Caching policy.')
  caching: ('ReadWrite' | 'ReadOnly' | 'None')

  @description('Disk size in GB.')
  diskSizeGB: int
}

@description('Data disk configuration type.')
type dataDiskType = {
  @description('Disk size in GB.')
  diskSizeGB: int

  @description('Logical unit number.')
  lun: int?

  @description('How the disk should be created.')
  createOption: ('Empty' | 'FromImage' | 'Attach')?

  @description('Storage account type.')
  storageAccountType: ('Premium_LRS' | 'StandardSSD_LRS' | 'Standard_LRS' | 'Premium_ZRS' | 'StandardSSD_ZRS')?

  @description('Caching policy.')
  caching: ('ReadWrite' | 'ReadOnly' | 'None')?
}

@description('NIC configuration type.')
type nicConfigType = {
  @description('Optional custom NIC name.')
  name: string?

  @description('The resource ID of the subnet.')
  subnetId: string

  @description('Enable accelerated networking.')
  enableAcceleratedNetworking: bool?

  @description('Network Security Group resource ID.')
  networkSecurityGroupId: string?

  @description('Private IP allocation method.')
  privateIPAllocationMethod: ('Dynamic' | 'Static')?

  @description('Static private IP address.')
  privateIPAddress: string?
}

@description('Role assignment configuration type.')
type roleAssignmentType = {
  @description('The principal ID (object ID) of the identity.')
  principalId: string

  @description('The role definition ID or built-in role name.')
  roleDefinitionIdOrName: string

  @description('The type of principal.')
  principalType: ('ServicePrincipal' | 'Group' | 'User' | 'ManagedIdentity')?
}
