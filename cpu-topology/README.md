# Get-VMCPUTopologyReport.ps1

This PowerShell script enumerates virtual machines on a vCenter Server and reports the CPU topology settings for those running hardware version 20 or higher. It highlights VMs that do not use the **Assigned on Power On** topology mode.

## Required Modules

- **VMware.PowerCLI** – provides `Connect-VIServer`, `Get-View` and other cmdlets used in the script.

PowerCLI is not bundled with Windows, so it must be installed prior to running the script.

### Install PowerCLI on Windows

Open an elevated PowerShell session and run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Install-Module -Name VMware.PowerCLI -Scope CurrentUser
```

PowerCLI 13 or later is recommended. The script has been validated with PowerShell 7 on Windows.

## Why use "Assigned on Power On"?

Starting in vSphere 8, CPU topology for new virtual machines defaults to **Assigned on Power On**. This allows ESXi to automatically choose the most efficient cores‑per‑socket configuration when the VM boots. According to VMware's *[vSphere 8.0 Virtual Topology: Performance Study](https://www.vmware.com/docs/vsphere8-virtual-topology-perf)*, automatic topology can:

- Remove the need to manually set cores per socket.
- Apply an optimal topology at the first power on and keep it consistent after vMotion migrations.
- Improve performance for database and other NUMA‑sensitive workloads (tests showed up to 14% better throughput in Oracle Database and 17% for Microsoft SQL Server).

## Usage

```powershell
./Get-VMCPUTopologyReport.ps1 -vCenter <vcenter-name> -Credential (Get-Credential)
```

Specify `-OutputPath <file.csv>` to export the results.

## Disclaimer

This script is intended for VMware administrators to **view** existing CPU topology settings. Always consider the application requirements before changing a VM's configuration. I hold no liability for the accuracy of the information produced by this script.
