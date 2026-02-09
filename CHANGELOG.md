# Changelog

All notable changes to this module will be documented in this file.

## [1.0.0] - Initial Release

### Added

- Virtual Machine resource deployment (Windows and Linux)
- Configurable VM size and OS image reference
- OS Disk configuration with storage account type, caching, and size
- Variable data disks support with per-disk LUN, size, and caching
- Variable NIC support with loop-based deployment
- Optional public IP (Standard SKU, static allocation)
- Accelerated networking support per NIC
- NSG association per NIC
- TrustedLaunch security profile
- Boot diagnostics
- Availability zone support
- Domain join extension (Windows only)
- Custom script extension (Windows and Linux)
- Diagnostic settings with Azure Monitor metrics
- Resource lock (CanNotDelete default)
- RBAC role assignments scoped to Resource Group
- Pester 5.x unit tests
- PSRule for Azure validation
- GitHub Actions workflows (static analysis, unit tests, ACR publish)
- Unique naming convention using `uniqueString(resourceGroup().id, subscription().id)`
