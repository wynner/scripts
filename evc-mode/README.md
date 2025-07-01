# evcmode.ps1

Reports virtual machines that could block enabling Enhanced vMotion Compatibility (EVC) mode on a VMware cluster. The script connects to vCenter and lists powered-on VMs with any manual CPUID overrides.

## Required Modules

- **VMware.PowerCLI** – used for `Connect-VIServer`, `Get-Cluster` and other VMware cmdlets.

## Disclaimer

This script is provided as is without any warranty. I hold no liability for the accuracy of the information produced by this script.
