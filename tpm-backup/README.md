# tpm-backup.ps1

Backs up TPM-based encryption recovery keys from ESXi hosts to a CSV file. The script connects to the specified vCenter, queries each host for its encryption mode and saves any recovery IDs and keys.

## Required Modules

- **VMware.PowerCLI** – provides the VMware cmdlets used to connect and query ESXi hosts.

## Disclaimer

This script is provided as is without any warranty. I hold no liability for the accuracy of the information produced by this script.
