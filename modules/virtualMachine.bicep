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

@description('Required. The size of the Virtual Machine.')
param vmSize string

@description('Required. Admin username for the VM.')
param adminUsername string

@description('Optional. Admin password for the VM. Required for Windows, optional for Linux if SSH key provided.')
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

@description('Optional. Data disks to attach.')
param dataDisks dataDiskType[] = []

@description('Required. Network interface IDs to attach. First NIC is primary.')
param networkInterfaceIds array

@description('Optional. Boot diagnostics storage account URI. Empty string disables boot diagnostics.')
param bootDiagnosticsStorageUri string = ''

@description('Optional. Availability zone for the VM.')
param availabilityZone string = ''

@description('Required. Resource tags.')
param tags object

// ============ //
// Variables    //
// ============ //

// Build network profile from NIC IDs
// For-expressions must be top-level variable declarations, not nested in objects
var formattedNetworkInterfaces = [for (nicId, i) in networkInterfaceIds: {
  id: nicId
  properties: {
    primary: i == 0
  }
}]

var networkProfile = {
  networkInterfaces: formattedNetworkInterfaces
}

// Build OS profile based on OS type
var windowsOsProfile = {
  computerName: take(vmName, 15) // Windows computer name max 15 chars
  adminUsername: adminUsername
  adminPassword: adminPassword
  windowsConfiguration: {
    provisionVMAgent: true
    enableAutomaticUpdates: true
    patchSettings: {
      patchMode: 'AutomaticByOS'
      assessmentMode: 'AutomaticByPlatform'
    }
  }
}

var linuxOsProfile = {
  computerName: vmName
  adminUsername: adminUsername
  adminPassword: empty(sshPublicKey) ? adminPassword : null
  linuxConfiguration: {
    disablePasswordAuthentication: !empty(sshPublicKey)
    ssh: !empty(sshPublicKey) ? {
      publicKeys: [
        {
          path: '/home/${adminUsername}/.ssh/authorized_keys'
          keyData: sshPublicKey
        }
      ]
    } : null
    provisionVMAgent: true
    patchSettings: {
      patchMode: 'AutomaticByPlatform'
      assessmentMode: 'AutomaticByPlatform'
    }
  }
}

var osProfile = osType == 'Windows' ? windowsOsProfile : linuxOsProfile

// Build storage profile
var storageProfile = {
  imageReference: imageReference
  osDisk: {
    name: '${vmName}-osdisk'
    createOption: osDisk.createOption
    managedDisk: osDisk.managedDisk
    caching: osDisk.caching
    diskSizeGB: osDisk.diskSizeGB
  }
  dataDisks: formattedDataDisks
}

var formattedDataDisks = [for (disk, i) in dataDisks: {
  name: '${vmName}-datadisk-${i}'
  lun: disk.?lun ?? i
  createOption: disk.?createOption ?? 'Empty'
  diskSizeGB: disk.diskSizeGB
  managedDisk: {
    storageAccountType: disk.?storageAccountType ?? 'Premium_LRS'
  }
  caching: disk.?caching ?? 'ReadOnly'
}]

// Boot diagnostics configuration
var diagnosticsProfile = !empty(bootDiagnosticsStorageUri) ? {
  bootDiagnostics: {
    enabled: true
    storageUri: bootDiagnosticsStorageUri
  }
} : {
  bootDiagnostics: {
    enabled: true
  }
}

// ============ //
// Resources    //
// ============ //

// Deploy Virtual Machine
// MSLearn: https://learn.microsoft.com/azure/templates/microsoft.compute/virtualmachines
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  tags: tags
  zones: !empty(availabilityZone) ? [ availabilityZone ] : null
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: osProfile
    storageProfile: storageProfile
    networkProfile: networkProfile
    diagnosticsProfile: diagnosticsProfile
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Virtual Machine.')
output resourceId string = virtualMachine.id

@description('The name of the Virtual Machine.')
output name string = virtualMachine.name

@description('The resource group the VM was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The location the resource was deployed into.')
output location string = virtualMachine.location

@description('The principal ID of the system-assigned managed identity (if applicable).')
output systemAssignedPrincipalId string = virtualMachine.?identity.?principalId ?? ''

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
