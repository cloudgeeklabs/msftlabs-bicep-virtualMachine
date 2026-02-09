# msftlabs-bicep-virtualMachine

Bicep Module for deploying Azure Virtual Machines (Windows and Linux) with enterprise security defaults, including variable NICs, optional public IP, data disks, extensions (domain join, custom script), diagnostics, resource locks, and RBAC.

## Details

This module deploys a fully-configured Azure Virtual Machine into a target resource group. It follows the standard Bicep module pattern used across all `msftlabs-bicep-*` modules, with reusable sub-modules for each concern.

### Features

- **Windows and Linux** VM support
- **Configurable VM size** and OS image reference
- **OS Disk** with storage type, caching, and size configuration
- **Variable data disks** with per-disk LUN, size, caching, and storage type
- **Variable NICs** (loop-based deployment, first NIC is primary)
- **Optional public IP** (Standard SKU, static allocation)
- **Accelerated networking** support per NIC
- **NSG association** per NIC
- **TrustedLaunch** security profile
- **Boot diagnostics** enabled by default
- **Availability zone** support
- **Domain join extension** (Windows only, `JsonADDomainExtension`)
- **Custom script extension** (Windows `CustomScriptExtension` / Linux `CustomScript`)
- **Diagnostic settings** with Azure Monitor metrics (default LAW fallback)
- **Resource lock** (`CanNotDelete` by default)
- **RBAC role assignments** scoped to Resource Group
- **Unique naming** using `uniqueString(resourceGroup().id, subscription().id)`
- **Tags** required on all resources

### Module Structure

```text
msftlabs-bicep-virtualMachine/
├── main.bicep                          # Orchestrator module
├── modules/
│   ├── virtualMachine.bicep            # VM resource
│   ├── nic.bicep                       # Network interface
│   ├── publicIp.bicep                  # Public IP address
│   ├── diagnostics.bicep               # Diagnostic settings
│   ├── lock.bicep                      # Resource lock
│   ├── rbac.bicep                      # RBAC role assignments
│   └── extensions.bicep                # VM extensions (domain join, custom script)
├── tests/
│   ├── virtualMachine.tests.ps1        # Pester 5.x tests
│   ├── test.parameters.json            # Sample parameter file
│   └── ps-rule.yaml                    # PSRule configuration
├── .github/workflows/
│   ├── static-test.yaml                # Bicep lint + PSRule
│   ├── unit-tests.yaml                 # Pester tests
│   └── deploy-module.yaml              # Publish to ACR on tag
├── CHANGELOG.md
├── README.md
└── .gitignore
```

## Usage

### Basic Linux VM

```bicep
module vm 'br:msftlabsbicepmods.azurecr.io/bicep/modules/virtualmachine:1.0.0' = {
  name: 'deploy-linux-vm'
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'centralus'
    osType: 'Linux'
    vmSize: 'Standard_B2ms'
    adminUsername: 'azureadmin'
    sshPublicKey: '<your-ssh-public-key>'
    imageReference: {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
    nicConfigs: [
      {
        subnetId: '<subnet-resource-id>'
      }
    ]
    tags: {
      project: 'myproject'
      environment: 'dev'
    }
  }
}
```

### Windows VM with Domain Join

```bicep
module vm 'br:msftlabsbicepmods.azurecr.io/bicep/modules/virtualmachine:1.0.0' = {
  name: 'deploy-windows-vm'
  params: {
    workloadName: 'myapp'
    environment: 'prod'
    location: 'centralus'
    osType: 'Windows'
    vmSize: 'Standard_D4s_v5'
    adminUsername: 'azureadmin'
    adminPassword: '<secure-password>'
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-g2'
      version: 'latest'
    }
    nicConfigs: [
      {
        subnetId: '<subnet-resource-id>'
        enableAcceleratedNetworking: true
      }
    ]
    enablePublicIp: false
    enableDomainJoin: true
    domainToJoin: 'corp.contoso.com'
    ouPath: 'OU=Servers,DC=corp,DC=contoso,DC=com'
    domainUsername: 'domainadmin@corp.contoso.com'
    domainPassword: '<domain-password>'
    dataDisks: [
      {
        diskSizeGB: 128
        lun: 0
        createOption: 'Empty'
        storageAccountType: 'Premium_LRS'
        caching: 'ReadOnly'
      }
    ]
    enableLock: true
    enableDiagnostics: true
    tags: {
      project: 'myproject'
      environment: 'prod'
    }
  }
}
```

## Parameters

| Parameter | Type | Required | Default | Description |
| --------- | ---- | -------- | ------- | ----------- |
| `workloadName` | string | Yes | - | Workload name (max 10 chars) |
| `location` | string | No | resourceGroup().location | Azure region |
| `environment` | string | No | `dev` | Environment (dev/test/prod) |
| `osType` | string | Yes | - | OS type (Windows/Linux) |
| `vmSize` | string | Yes | - | VM size SKU |
| `adminUsername` | string | Yes | - | Admin username |
| `adminPassword` | securestring | No | `''` | Admin password (required for Windows) |
| `sshPublicKey` | string | No | `''` | SSH public key (Linux) |
| `imageReference` | object | Yes | - | OS image reference |
| `osDisk` | object | No | Premium_LRS, 128GB | OS disk configuration |
| `dataDisks` | array | No | `[]` | Data disk configurations |
| `nicConfigs` | array | Yes | - | NIC configurations |
| `enablePublicIp` | bool | No | `false` | Enable public IP |
| `availabilityZone` | string | No | `''` | Availability zone |
| `enableDomainJoin` | bool | No | `false` | Enable domain join |
| `enableCustomScript` | bool | No | `false` | Enable custom script extension |
| `diagnosticWorkspaceId` | string | No | Default LAW | Log Analytics workspace ID |
| `enableDiagnostics` | bool | No | `true` | Enable diagnostics |
| `enableLock` | bool | No | `true` | Enable resource lock |
| `lockLevel` | string | No | `CanNotDelete` | Lock level |
| `roleAssignments` | array | No | `[]` | RBAC role assignments |
| `tags` | object | Yes | - | Resource tags |

## Outputs

| Output | Type | Description |
| ------ | ---- | ----------- |
| `resourceId` | string | VM resource ID |
| `name` | string | VM name |
| `resourceGroupName` | string | Resource group name |
| `location` | string | Deployment location |
| `vmName` | string | Generated VM name |
| `nicResourceIds` | array | NIC resource IDs |
| `nicPrivateIPs` | array | NIC private IP addresses |
| `publicIpAddress` | string | Public IP (if enabled) |
| `environment` | string | Environment identifier |
| `uniqueSuffix` | string | Generated unique suffix |

## ACR Reference

```text
br:msftlabsbicepmods.azurecr.io/bicep/modules/virtualmachine:<version>
```

## Testing

```powershell
# Run Pester tests
Invoke-Pester -Path ./tests/virtualMachine.tests.ps1 -Output Detailed

# Build validation
az bicep build --file main.bicep
```
