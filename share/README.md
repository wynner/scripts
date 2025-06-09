# vSphere Health Check — RVTools-Driven Assessment

A **PowerShell 7+** script that turns a single **RVTools** export (`.xlsx`) into a comprehensive, TAM‑style health‑check for VMware vSphere environments (6.0 → 8.0 U3 & VCF 5.x).


**Outputs**

- **Detailed findings** (`CSV`)
- **Environment summary** (`JSON`) — vCenters, hosts, clusters, VMs, billable cores
- Colour‑coded console overview (Critical → Info)
- **140+ Checks** across security, patching, sizing, storage, network, licensing & VM hygiene
- Zero vCenter credentials required — fully offline from the RVTools export
- Auto‑installs **ImportExcel** (if not already present)

> Ideal for VMware TAMs, consultants, ops teams and auditors who need a human‑readable report without Skyline or PowerCLI access.

---


## Required PowerShell Modules

This script requires the following PowerShell modules to be installed:

- `ImportExcel` — Parses and exports `.xlsx` files from RVTools  
  - Auto-installs if not present when the script is run
- `ThreadJob` — Enables parallel processing via `ForEach-Object -Parallel`  
  - Built into PowerShell 7+
- `VMware.PowerCLI` (optional) — Required only if you extend the script for live vCenter connections or comparisons  
  - Includes cmdlets like `Get-VM`, `Get-VMHost`, `Get-Datastore`, etc.
- `PowerVCF` (optional) — Required for integration with VCF APIs or SDDC Manager
- `PowerNSX` or `VMware.Sdk.Nsx.Policy` (optional) — For NSX-v or NSX-T extensions
- `PSWriteWord` (optional) — To generate Word `.docx` reports on Windows or macOS using OpenXML (no Office dependency)

To install manually:

```powershell
Install-Module ImportExcel -Scope CurrentUser
Install-Module ThreadJob -Scope CurrentUser
Install-Module VMware.PowerCLI -Scope CurrentUser
Install-Module PowerVCF -Scope CurrentUser
Install-Module PSWriteWord -Scope CurrentUser
```

## Quick start

```powershell
# 1. Place RVTools .xlsx exports in a folder (e.g., ./input)
# 2. Run the wrapper script to process all files in parallel
pwsh Run-AllRVToolsCheck-v3.ps1 -InputFolder ./input -RunParentDir ./runs
```

## Repository Overview

The project is organised around two main scripts and a set of modules:

- **Run-AllRVToolsCheck-v3.ps1** — spawns a parallel job for each RVTools export and writes results under `vsphere-health-check-runs/`.
- **vSphere-HealthCheckv3.ps1** — processes a single workbook, loads all modules and records findings.
- **modules/** — contains the logic for each category of checks such as hosts, clusters, networking and storage. Helper functions live under `modules/logging/` while build and hardware tables are in `modules/builds/` and `modules/hardware/`.
- Findings are captured via `Add-Finding` from `modules/logging/FindingHelpers.ps1` and exported as CSV and JSON.

If you are new to the codebase, browse the modules to see how tests are implemented and review the lookup tables to understand version mappings.
=======
## Severity Levels

Findings are categorised from **Critical** down to **Info**. The rationale for
each level and example scenarios are documented in
[docs/SeverityGuidelines.md](docs/SeverityGuidelines.md). Use these guidelines
when reviewing or adjusting tests.

Additional detail on the CPU fallback logic can be found in
[docs/CpuModelToEvcLookup.md](docs/CpuModelToEvcLookup.md).

## Parameters

### Run-AllRVToolsCheck-v3.ps1

| Parameter        | Required? | Description                                      |
|------------------|-----------|--------------------------------------------------|
| `-InputFolder`   | Yes       | Path to folder containing `.xlsx` files          |
| `-RunParentDir`  |           | Parent folder for output. Default: `../runs`     |

### vSphere-HealthCheckv3.ps1 (called per file)

| Parameter         | Required? | Description                                                    |
|-------------------|-----------|----------------------------------------------------------------|
| `-RvToolsPath`    | Yes       | Path to the RVTools XLSX export                                |
| `-OutputCsv`      |           | Write findings to CSV (optional, otherwise console-only)       |
| `-SkipVMChecks`   |           | Skip VM-level rules (infra-only mode)                          |
| `-VerboseTest`    |           | Enable VerboseTest mode to include informational (Info-level) tests |

---

## Rule Coverage

A comprehensive set of over **140+ automated tests** are grouped into the following categories:

### vCenter Server

- vCenter not on latest patch (per build history)
- vCenter on evaluation license
- vCenter license expired or expiring soon
- vCenter build newer than supported by hosts
- vCenter/ESXi compatibility (per Broadcom KB 314601)
- vCenter minor upgrade blocked by incompatible host versions
- vCenter certificate expired or expiring soon

### ESXi Host Lifecycle & Patching

- ESXi not on latest patch
- ESXi newer than vendor-certified max version
- Host capable of newer ESXi than currently installed
- Host build string malformed or unknown
- Host config status: RED, YELLOW, GRAY
- Host in maintenance mode
- Host in quarantine mode
- Host profile non-compliant
- Core dump not configured
- Host certificate expired or expiring soon
- Host with unidentified hardware model
- CPU pCore count mismatch
- Hyper-Threading (HT) inactive
- vSAN Witness running on unsupported CPU
- vSAN Witness appliance on unsupported ESXi version (< 7.0)
- Power policy not 'High Performance'

### Cluster Configuration

- HA disabled
- DRS disabled
- DRS in Manual mode
- DRS in Partially Automated mode
- Isolation response not set
- DRS migration threshold too low
- DRS migration threshold too high
- EVC baseline inconsistent / missing
- Cluster with only one host
- Host not in any cluster
- Standalone host with VMs powered on
- Single-host cluster with VMs powered on
- Cluster reserved RAM utilization summary (Reserved vs total memory)
- Cluster defined but has no hosts
- Cluster EVC mode blocks vMotion
- Cluster DRS/HA settings inconsistent
- HA fail-over in progress

### Time & DNS Configuration

- NTP daemon not running
- Only one NTP server defined
- DNS servers missing
- DNS Search Domains missing
- Inconsistent NTP/DNS/Search Domain config across cluster
- Time drift > 60 seconds

### Host Sizing & Capacity

- CPU oversubscription ratio > 6:1
- vCPU count > host physical cores
- Memory oversubscription based on vRAM vs host RAM
- CPU Hot Add / Remove enabled
- Memory Hot Add enabled
- Memory ballooned or swapped
- vCPU or memory reservation configured unnecessarily
- Host fails VCF minimum core rule

### Storage

- vSAN free space < 25%
- VMFS datastore free space < 20%
- Thin-provisioned shared disks
- Snapshots > 72 hours
- Snapshot chain depth > 3
- Snapshots on shared-disk VMs
- Shared disks not IndependentPersistent
- Multi-writer VMDKs span datastores
- Raw Device Mappings (RDMs) not best-practice
- VMs on local-only datastores
- APD/PDL or dead SCSI paths detected
- Datastore not accessible to all hosts in cluster
- Datastore accessibility evaluated per cluster it's mounted to
- Multipath policy not Round Robin (3PAR/DGC/SYNOLOGY)
- Inconsistent path count across hosts
- Datastore with no active path to at least one host
- Datastore with single active path to at least one host
- Datastore with non-uniform number of paths per host
- Datastore with >=2 active paths

### Licensing

- vCenter on eval license
- vCenter license expired
- Host under-licensed for VCF
- Host fails VCF minimum core rule

### VM Hygiene & Configuration

- Outdated or missing VMware Tools
- VM hardware version too old
- Secure Boot not enabled
- Unknown or stale VM power state
- Disconnected VMs
- VMs missing annotations
- EFI Secure Boot not enabled
- VM firmware not set to EFI where required
- VM with memory hot-add enabled
- VM with CPU hot-add enabled
- VM with orphaned state
- VM with stale snapshot
- VM with excessive snapshot chain depth
- Snapshot consolidation required
- VM with RDM disk in use
- VM on local-only datastore
- VM with ballooned or swapped memory
- VM with thin-provisioned shared disk
- VM with multi-writer VMDKs on multiple datastores

### Resource Pool Hygiene

- Resource Pool CPU/mem limits defined
- Usage exceeding reservation
- Excessive VMs in resource pool
- CPU/memory maxed or nearing limit
- CPU or memory reservation near/at limit
- VCD organization VDCs detected

### Networking

- VMkernel MTU mismatch
- Hosts missing from dvSwitch
- dvSwitch MTU inconsistent
- VLAN 4095 (trunked) Port Group check
- dvPort-group security flags (Promiscuous Mode, MAC Changes, Forged Transmits)
- Port group security flags (Promiscuous Mode, MAC Changes, Forged Transmits)
- dvSwitch/portgroup not present on all hosts
- Host using sub-10Gb interfaces
- Mismatched NIC speeds on switch
- NIC link down while connected to switch
- NIC half duplex
- DHCP enabled on vmkernel
- VMkernel IP bound to sub-10Gb NIC
- VMkernel IP bound to down NIC
- VMkernel subnet mask mismatch
- Inconsistent VMkernel Gateway (IPv4/IPv6)
- Inconsistent VMkernel ID-to-PortGroup mapping
- Duplicate vmkernel IP address
- IPv6 address configuration inconsistencies
- Non-uniform NIC switch assignment
- Inconsistent PortGroup names for same VLAN
- Host only uses Standard vSwitch(es)
- Legacy dvSwitch version blocks ESXi 8.0 upgrade
- dvSwitch upgrade available
- dvSwitch at latest version

---

## Sample Output Directory

```
vsphere-health-check-runs/
└── Run-2025-05-11_18-20-10/
    ├── cpu_model_dump/
    │   └── cpu_models.csv
    ├── input1-output.csv
    ├── input1-output.json
    ├── input1-output-EnvSummary.json
    ├── input1-output-EnvFindings.json
    ├── rvtools-summary.json
    ├── rvtool-findings.json
    └── rvtool-findings.csv
```

## How It Works

### CPU Model → EVC Lookup

When RVTools does not populate the **MaxEVCKey** column, the script falls back
to [`CpuModelToEvcLookup.ps1`](modules/evc/CpuModelToEvcLookup.ps1). This file
defines a hashtable mapping CPU model strings to objects containing the
expected core count (**Cores**) and the **Evc** baseline key. During cluster
checks the host's *CPU Model* text is used as a lookup key. If a match is found,
that EVC baseline is used for compatibility tests.

You can extend the table by editing the hashtable. Exact string matches are the
simplest option, but `[regex]` keys are also supported. Below are two example
entries:

```powershell
# Exact match
'AMD EPYC 7502P 32-Core Processor' = @{ Cores = 32; Evc = 'amd-milan' }

# Regex pattern to match any 6130 CPU variant
[regex]'Intel\(R\) Xeon\(R\) Gold 6130.*' = @{ Cores = 16; Evc = 'intel-skylake' }
```

An optional utility script is included that queries the Intel CPU database and
generates an updated mapping file. Running it periodically keeps the table in
sync with newly released processors.

## Compatibility

This script has been tested with the following platforms:

### RVTools Versions
- Tested: `4.4.1.0`, `4.7.1.4`
- Actively developed against: `4.7.1.4`

### vCenter Server Versions
- Tested with: `6.7`, `7.0`, `8.0`

### ESXi Host Versions
- Tested with: `6.0`, `6.5`, `6.7`, `7.0`, `8.0`

1. **Input:** Expects one or more RVTools `.xlsx` exports.
2. **Parallel Execution:** Each file is checked using `vSphere-HealthCheckv3.ps1` in parallel.
3. **Output:**
   - `*-output.csv`: Health check results
   - `*-output.json`: Full findings as JSON
   - `*-output-EnvSummary.json`: Host/cluster/VM/core stats
   - `*-output-EnvFindings.json`: Counts by category/test/severity
4. **Consolidated Files:**
   - `rvtools-summary.json`: Combined environment stats
   - `rvtool-findings.json`: Combined finding summary
   - `rvtool-findings.csv`: Flattened view of all test outputs
   - `cpu_model_dump/cpu_models.csv`: List of CPU models with core counts and max EVC

### PowerShell Versions
- Tested with: `7.4.5`, `7.5.1`
- Development is currently focused on compatibility with PowerShell `7.5.1`

## Installation

```powershell
# One‑liner (PowerShell 7+)
irm https://raw.githubusercontent.com/wynner/rvtools-health/main/Invoke-RvToolsHealth.ps1 -o Invoke-RvToolsHealth.ps1

# Optional: install as module
Install-Script Invoke-RvToolsHealth -Scope CurrentUser
```

The script auto‑installs **ImportExcel** (from PSGallery) to parse the XLSX.

---

\## Sample output

```
=====================  Environment Summary  =====================
► ESXi Hosts                      42
► Clusters                         5
► Virtual Machines             1 372
► VCF core licence projection  1 312 cores

===== Critical Severity Findings =====
Host      Not on latest patch for ESXi          5
Storage   vSAN free space <25 %                 2
Security  Host certificate EXPIRED              1
...
```

---

\## Limitations & roadmap

- Does **not** inspect vSAN object health, NSX‑T, or vLCM desired‑state (needs APIs/Skyline)
- Assumes host, cluster and datastore names are unique. If an RVTools workbook
  combines multiple vCenters with overlapping names the results may be skewed.
- Firmware driver validation planned for v3 (requires IODevices JSON feed)
- CI pipeline will soon publish notarised binaries for macOS & Windows Jump Hosts

---

\## Contributing
Issues & PRs welcome! Please include:

- Sample redacted RVTools XLSX exhibiting the edge‑case
- PowerShell 7 test run (`pwsh -Version`) output
- Expected vs actual findings table

---

## Licence

This is a **personal project** created and maintained by Ross Wynne.

**No license is granted to copy, modify, redistribute, or use this code** in any form without explicit written permission from the author.

If you wish to use any portion of this code for internal, educational, or commercial purposes, please contact me first.