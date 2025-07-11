# vSphere Health Check Tests

The table below lists all findings generated by the health check scripts.\n
| Category | Test Name | Severity | Description | VCF 9.0 Import | Date |
|---------|-----------|---------|-------------|---------------|------|
| Cluster | Admission Control Disabled | Info | Detects clusters where Admission Control is disabled, risking overcommitment during host failure scenarios. | No | 2025-06-26 |
| Cluster | Admission Control Enabled | Info | Identifies clusters with Admission Control enabled; review settings to ensure adequate failover capacity. | No | 2025-06-26 |
| Cluster | DRS automation level: Manual | Critical | Identifies clusters where DRS automation is set to Manual, requiring admins to manually balance workloads. | No | 2025-06-26 |
| Cluster | DRS automation level: Partially Automated | Medium | Highlights clusters with DRS set to Partially Automated, where placement is automatic but migrations require manual intervention. | No | 2025-06-26 |
| Cluster | DRS disabled | High | Detects clusters with DRS disabled, which may result in unbalanced workloads and manual VM placement. | Yes | 2025-06-26 |
| Cluster | DRS migration threshold set to 1 (very conservative) | High | Shows clusters with DRS migration threshold set to very conservative, limiting automatic migrations and potentially reducing load balancing efficiency. | No | 2025-06-26 |
| Cluster | DRS migration threshold set to 2 (conservative) | Medium | Indicates DRS migration threshold set to conservative, reducing frequency of automated migrations. | No | 2025-06-26 |
| Cluster | DRS migration threshold set to 4 (aggressive) | Medium | Indicates DRS migration threshold set to aggressive, increasing the number of automated VM migrations for balancing. | No | 2025-06-26 |
| Cluster | DRS migration threshold set to 5 (very aggressive) | High | Shows clusters with DRS migration threshold set to very aggressive, which may cause excessive VM migrations. | No | 2025-06-26 |
| Cluster | Empty cluster |   | Flags clusters with no hosts; may indicate unused or misconfigured clusters. | Yes | 2025-06-26 |
| Cluster | HA fail-over in progress |   | Detects clusters where HA is currently recovering from a host failure; monitor for availability and remediation. | Yes | 2025-06-26 |
| Cluster | Incomplete vSAN Fault Domain configuration | Medium | Identifies vSAN clusters with incomplete Fault Domain setup, risking reduced resilience against rack or site failures. | No | 2025-06-26 |
| Cluster | Inconsistent DNS search domains | High | Alerts when DNS search domains are not uniform across hosts in a cluster, which may cause name resolution issues. | Yes | 2025-06-26 |
| Cluster | Inconsistent DNS server list | High | Notifies if DNS server lists differ between hosts, potentially causing inconsistent name resolution. | Yes | 2025-06-26 |
| Cluster | Inconsistent NTP servers | High | Identifies clusters where NTP server configuration is not consistent, risking time drift and authentication failures. | Yes | 2025-06-26 |
| Cluster | Inconsistent VMkernel Gateway (IPv4) | High | Detects clusters where VMkernel IPv4 gateways differ, which can impact network connectivity for vMotion or storage. | No | 2025-06-26 |
| Cluster | Inconsistent VMkernel Gateway (IPv6) | High | Detects clusters where VMkernel IPv6 gateways differ, which can impact network connectivity for vMotion or storage. | No | 2025-06-26 |
| Cluster | Inconsistent host memory in cluster | Medium | Flags clusters where hosts have different memory sizes, which may affect DRS and HA resource calculations. | No | 2025-06-26 |
| Cluster | Isolation response incorrect for vSAN | High | Identifies clusters where HA isolation response is not optimal for vSAN, risking data availability during isolation events. | No | 2025-06-26 |
| Cluster | Isolation response should be checked for FC Storage | Info | Suggests reviewing HA isolation response for clusters using FC storage to avoid VM downtime during network isolation. | No | 2025-06-26 |
| Cluster | Memory oversubscription | High | Detects clusters where total VM memory exceeds physical memory, potentially causing swapping and performance issues. | No | 2025-06-26 |
| Cluster | Mixed ESXi major versions | Medium | Flags clusters running different ESXi major versions, which can complicate management and compatibility. | No | 2025-06-26 |
| Cluster | Non-uniform NIC switch assignment | High | Identifies clusters where hosts have different NIC-to-switch mappings, risking inconsistent network connectivity. | No | 2025-06-26 |
| Cluster | Single-host cluster |   | Highlights clusters with only one host, which lack redundancy for HA and DRS. | Yes | 2025-06-26 |
| Cluster | Single-host cluster with VMs powered on | High | Warns of single-host clusters running VMs, risking VM uptime if the host fails. | Yes | 2025-06-26 |
| Cluster | Stretched vSAN with <8 hosts | Info | Detects stretched vSAN clusters with fewer than 8 hosts, which may not meet recommended resiliency guidelines. | Yes | 2025-06-26 |
| Cluster | Total CPU reservations (VMs + Resource Pools) | Info | Reports total CPU reservations in the cluster; excessive reservations can impact admission control and resource allocation. | No | 2025-06-26 |
| Cluster | Total CPU reservations (maintenance hosts removed) | Info | Calculates CPU reservations excluding hosts in maintenance mode, highlighting potential resource shortfalls. | No | 2025-06-26 |
| Cluster | Total CPU reservations if one active host lost | Info | Estimates CPU reservation capacity if a host fails, helping assess HA readiness. | No | 2025-06-26 |
| Cluster | Total memory reservations (VMs + Resource Pools) | Info | Reports total memory reservations in the cluster; high reservations can limit VM deployment flexibility. | No | 2025-06-26 |
| Cluster | Total memory reservations (maintenance hosts removed) | Info | Calculates memory reservations excluding hosts in maintenance mode, exposing possible overcommitment. | No | 2025-06-26 |
| Cluster | Total memory reservations if one active host lost | Info | Estimates memory reservation impact if a host fails, supporting HA capacity planning. | No | 2025-06-26 |
| Cluster | VxRail cluster detected | Info | Identifies clusters managed by VxRail; may require specific update or support procedures. | Yes | 2025-06-26 |
| Cluster | VxRail vSAN multi-rack fault domain configuration | Info | Alerts if VxRail vSAN clusters have or lack multi-rack fault domains, which affects failure domain resilience. | Yes | 2025-06-26 |
| Cluster | VxRail vSAN stretched cluster detected | Info | Detects VxRail clusters configured as stretched vSAN, which have special operational requirements. | Yes | 2025-06-26 |
| Cluster | vSAN multi-rack fault domain configuration | Info | Flags vSAN clusters with multi-rack fault domains, highlighting advanced configuration for rack-level resilience. | Yes | 2025-06-26 |
| Cluster | vSAN stretched cluster detected | Info | Detects vSAN clusters configured for stretched operation, requiring additional monitoring and design considerations. | Yes | 2025-06-26 |
| Cluster EVC | All hosts compatible for cross-cluster vMotion | Info | Confirms that all hosts are able to support cross-cluster vMotion, ensuring seamless VM mobility and minimizing risk of migration failures due to CPU incompatibility. | No | 2025-06-26 |
| Cluster EVC | Cross-cluster vMotion incompatibility summary | High | Summarizes CPU or EVC configuration issues that prevent vMotion between clusters, which can disrupt workload balancing and disaster recovery operations. | No | 2025-06-26 |
| Cluster EVC | EVC can be raised | Low | Indicates that the EVC (Enhanced vMotion Compatibility) mode can be increased, allowing for newer VM hardware versions and improved feature support without compromising vMotion compatibility. | No | 2025-06-26 |
| Cluster EVC | EVC configured and appropriate | Info | Verifies that EVC is set correctly for the cluster’s CPU mix, reducing the risk of vMotion failures and ensuring operational consistency. | No | 2025-06-26 |
| Cluster EVC | EVC disabled with mixed CPU gens | High | Flags clusters where EVC is disabled despite hosts having different CPU generations, increasing the likelihood of vMotion failures and VM compatibility issues. | No | 2025-06-26 |
| Cluster EVC | EVC disabled with uniform CPU gen | Low | Notes that EVC is disabled but all hosts share the same CPU generation, which is currently safe but may introduce issues if hardware is added in the future. | No | 2025-06-26 |
| Cluster EVC | EVC enabled with unsupported CPU family | High | Warns that EVC is enabled on hosts with unsupported CPU families, which may prevent VMs from starting or migrating successfully. | No | 2025-06-26 |
| Cluster EVC | EVC mode below max allowed for CPUs | Low | Identifies clusters where EVC mode is set lower than the maximum supported by the hardware, potentially limiting VM capabilities and features unnecessarily. | No | 2025-06-26 |
| Cluster EVC | EVC mode exceeds VC supported max | High | Detects when the EVC mode is set higher than the vCenter Server supports, risking unexpected vMotion or VM compatibility problems. | No | 2025-06-26 |
| Cluster EVC | EVC optimal for mixed CPU gens | Info | Confirms that EVC is optimally configured for clusters with mixed CPU generations, ensuring maximum compatibility for vMotion. | No | 2025-06-26 |
| Cluster EVC | EVC set to max for uniform CPU gen | Info | Indicates that EVC is set to the highest supported level for clusters with uniform CPU generations, maximizing feature availability and compatibility. | No | 2025-06-26 |
| Cluster EVC | Mixed CPU vendors in cluster | High | Flags clusters containing hosts from different CPU vendors (e.g., Intel and AMD), which prevents EVC from being enabled and blocks vMotion between hosts. | No | 2025-06-26 |
| Cluster EVC | Powered-on VMs at risk due to missing EVC | Medium | Warns that powered-on VMs are running in clusters without EVC, increasing the risk of vMotion failures or outages during host maintenance or failure. | No | 2025-06-26 |
| Cluster EVC | VMHW blocks vMotion to some hosts | High | Identifies VMs with hardware versions incompatible with certain hosts, which can block vMotion and complicate maintenance or failover. | No | 2025-06-26 |
| Cluster EVC | VMHW newer than EVC baseline (advisory) | Low | Advises that VM hardware versions exceed what is supported by the EVC baseline, potentially limiting vMotion options and advanced features. | No | 2025-06-26 |
| Cluster EVC | vCenter version unknown for cluster | Medium | Indicates that the vCenter Server version managing the cluster is unknown, making it difficult to assess compatibility and support status. | No | 2025-06-26 |
| Host | CPU model unknown - Max EVC not found | Low | Alerts when a host’s CPU model cannot be identified, preventing determination of the highest supported EVC mode and risking vMotion or compatibility issues. | No | 2025-06-26 |
| Host | CPU pCore count mismatch | Low | Detects hosts with mismatched physical core (pCore) counts, which can affect DRS, HA, and workload balancing efficiency. | No | 2025-06-26 |
| Host | ESXi version exceeds certified hardware support | Critical | Test checks for: ESXi version exceeds certified hardware support | Yes | 2025-06-26 |
| Host | ESXi version matches hardware certification limit | Info | Reports hosts running an ESXi version that matches the maximum certified by the hardware vendor, signaling the need to plan for hardware upgrades before future ESXi updates. | No | 2025-06-26 |
| Host | Host hardware supports newer ESXi version | Info | Indicates that the host’s hardware is certified for a newer ESXi version, highlighting upgrade opportunities to improve security and features. | No | 2025-06-26 |
| Host | Host not in a cluster |   | Flags standalone hosts not assigned to any cluster, which limits their access to DRS, HA, and shared resource management. | Yes | 2025-06-26 |
| Host | Host supports up to ESXi 6.7 | Info | Identifies hosts whose hardware is only certified up to ESXi 6.7, restricting future upgrade paths and support. | Yes | 2025-06-26 |
| Host | Host supports up to ESXi 7.0 | Info | Identifies hosts whose hardware is only certified up to ESXi 7.0, restricting future upgrade paths and support. | Yes | 2025-06-26 |
| Host | Host supports up to ESXi 8.0 | Info | Identifies hosts whose hardware is only certified up to ESXi 8.0, restricting future upgrade paths and support. | No | 2025-06-26 |
| Host | Host supports up to ESXi 9.0 | Info | Identifies hosts whose hardware is only certified up to ESXi 9.0, restricting future upgrade paths and support. | No | 2025-06-26 |
| Host | Invalid ESXi label format | High | Detects hosts with invalid ESXi label formats, which can complicate inventory management, automation, and reporting. | No | 2025-06-26 |
| Host | Running ESXi unsupported by CPU | Critical | Warns that ESXi is running on a CPU not officially supported, increasing the risk of instability, lack of vendor support, and upgrade issues. | Yes | 2025-06-26 |
| Host | Standalone host with VMs powered on | High | Highlights standalone hosts (not in a cluster) that have running VMs, increasing risk of VM downtime due to lack of HA or DRS. | Yes | 2025-06-26 |
| Host | Time drift >60 s | Critical | Detects hosts with system clocks drifting by more than 60 seconds, risking authentication failures, log inconsistencies, and application errors. | No | 2025-06-26 |
| Host | Unidentifiable hardware model | Info | Flags hosts where the hardware model cannot be determined, complicating support, lifecycle management, and compatibility assessments. | Yes | 2025-06-26 |
| Host | Unidentified hardware | High | Identifies hosts with unknown or unrecognized hardware, which may lead to support and compatibility issues. | No | 2025-06-26 |
| Host | vSAN Witness running on unsupported CPU | Critical | Warns that a vSAN Witness appliance is running on a CPU that is not supported, potentially jeopardizing vSAN cluster reliability and supportability. | Yes | 2025-06-26 |
| Host Config | Core dump not configured | Low | Detects hosts without a configured core dump destination, which may hinder troubleshooting after a system crash. | No | 2025-06-26 |
| Host Config | Host in maintenance mode | Medium | Identifies hosts currently in maintenance mode, which are unavailable for workloads and may impact cluster capacity. | No | 2025-06-26 |
| Host Config | Host in maintenance mode - single-node cluster | Medium | Warns that the only host in a single-node cluster is in maintenance mode, resulting in total loss of compute resources for that cluster. | No | 2025-06-26 |
| Host Config | Host in maintenance mode - standalone host | Medium | Flags standalone hosts in maintenance mode, making all VMs on that host unavailable. | No | 2025-06-26 |
| Host Config | Host in quarantine mode | Medium | Identifies hosts in quarantine mode, which are excluded from DRS placements and may indicate underlying hardware or configuration issues. | No | 2025-06-26 |
| Host Config | Host in quarantine mode - single-node cluster | Medium | Warns that the only host in a single-node cluster is in quarantine mode, risking workload unavailability. | No | 2025-06-26 |
| Host Config | Host in quarantine mode - standalone host | Medium | Flags standalone hosts in quarantine mode, which may disrupt all workloads on that host. | No | 2025-06-26 |
| Host Config | Host missing DNS search domains |   | Detects hosts missing DNS search domains, which can cause name resolution failures and impact management operations. | Yes | 2025-06-26 |
| Host Config | Host missing DNS servers |   | Identifies hosts lacking DNS server configuration, risking failures in name resolution and management connectivity. | No | 2025-06-26 |
| Host Config | Host missing NTP servers | High | Flags hosts without NTP servers configured, increasing risk of time drift and related authentication or logging issues. | Yes | 2025-06-26 |
| Host Config | Host profile NON-compliant | High | Reports hosts not compliant with their assigned host profile, indicating configuration drift and potential operational risks. | No | 2025-06-26 |
| Host Config | Host status GRAY | High | Identifies hosts reporting a GRAY status, which may indicate loss of connectivity or monitoring issues. | Yes | 2025-06-26 |
| Host Config | Host status RED | High | Flags hosts with a RED status, indicating a critical fault or loss of functionality. | Yes | 2025-06-26 |
| Host Config | Host status YELLOW | Medium | Detects hosts with a YELLOW status, signaling warnings or potential issues that may require investigation. | No | 2025-06-26 |
| Host Config | NTP daemon not running | High | Identifies hosts where the NTP service is not running, risking time synchronization problems. | Yes | 2025-06-26 |
| Host Config | Only one NTP server | Medium | Warns that only a single NTP server is configured, reducing resilience and increasing risk of clock drift if that server becomes unavailable. | No | 2025-06-26 |
| Host Performance | CPU oversubscription ratio exceeded | Medium | Detects hosts where the ratio of vCPUs to physical cores exceeds recommended limits, risking performance degradation and scheduling delays. | No | 2025-06-26 |
| Host Performance | Hyper-Threading inactive | Low | Identifies hosts where Hyper-Threading is disabled or inactive, which may reduce available compute resources and impact performance. | No | 2025-06-26 |
| Host Performance | Memory oversubscription ratio exceeded | Critical | Flags hosts where allocated VM memory exceeds physical memory by a significant margin, increasing risk of swapping and performance issues. | No | 2025-06-26 |
| Host Performance | Power policy not High Performance | Medium | Detects hosts not set to High Performance power policy, which may limit CPU frequency and impact workload performance. | No | 2025-06-26 |
| Host Security | Host certificate EXPIRED | Critical | Warns that a host's security certificate has expired, which can disrupt management connectivity and increase security risk. | Yes | 2025-06-26 |
| NSX-T | NSX-T DHCP enabled on vmk10/11/50 | Info | Detects NSX-T DHCP enabled on specific vmkernel interfaces, which may be unintended and could introduce network configuration risks. | No | 2025-06-26 |
| NSX-v | NSX-v Edges Detected | High | Identifies the presence of NSX-v Edge devices, which may require special consideration for migration or support as NSX-v approaches end of support. | Yes | 2025-06-26 |
| NSX-v | NSX-v enabled cluster | High | Flags clusters with NSX-v enabled, highlighting dependencies on legacy network virtualization technology. | Yes | 2025-06-26 |
| NSX-v | VMs on VXLAN-backed networks | High | Detects VMs connected to VXLAN-backed networks, which may complicate migration to NSX-T or other network platforms. | No | 2025-06-26 |
| Networking | DHCP enabled on vmkernel | Medium | Detects vmkernel interfaces configured for DHCP, which can result in unpredictable management or storage IP addresses and impact connectivity. | Yes | 2025-06-26 |
| Networking | Duplicate vmkernel IP address | High | Flags duplicate IP addresses assigned to vmkernel interfaces, causing network conflicts and potential outages. Duplicates solely on the `BMC_Network` or `pgUSB` portgroups are ignored. | No | 2025-06-26 |
| Networking | Host only uses Standard vSwitch(es) |   | Identifies hosts using only Standard vSwitches, which may lack centralized network management and advanced features of distributed switches. | Yes | 2025-06-26 |
| Networking | Host using sub-10Gb interfaces | Medium | Detects hosts using network interfaces below 10Gbps, which may create performance bottlenecks for modern workloads. | Yes | 2025-06-26 |
| Networking | IPv6 configured but only non-routable addresses present on vmkernels in cluster | Info | Warns that vmkernel interfaces have IPv6 enabled but only non-routable addresses assigned, preventing external IPv6 connectivity. | No | 2025-06-26 |
| Networking | IPv6 not in use on any vmkernel in cluster | Info | Indicates that IPv6 is not used on any vmkernel interface, which may be a concern for environments requiring dual-stack or IPv6-only networking. | No | 2025-06-26 |
| Networking | IPv6 routable addresses partially configured on vmkernels in cluster | Low | Flags clusters where only some vmkernel interfaces have routable IPv6 addresses, leading to inconsistent connectivity. | No | 2025-06-26 |
| Networking | IPv6 routable addresses present on all vmkernels in cluster | Info | Confirms that all vmkernel interfaces have routable IPv6 addresses, supporting consistent dual-stack or IPv6 networking. | No | 2025-06-26 |
| Networking | Inconsistent PortGroup names for same VLAN | High | Detects inconsistent PortGroup naming for the same VLAN across hosts, which can complicate automation and increase risk of misconfiguration. | No | 2025-06-26 |
| Networking | Inconsistent VMkernel ID-to-PortGroup mapping | Medium | Identifies mismatches between VMkernel interface IDs and their associated PortGroups, risking connectivity and operational confusion. | No | 2025-06-26 |
| Networking | Inconsistent dvSwitch MTUs within cluster | Medium | Flags clusters with varying MTU sizes on distributed switches, which can cause fragmentation or connectivity issues for jumbo frame traffic. | No | 2025-06-26 |
| Networking | Mismatched NIC speeds on switch | High | Detects network switches with attached NICs operating at different speeds, which may cause performance inconsistencies. | No | 2025-06-26 |
| Networking | NIC half duplex | High | Identifies NICs operating in half-duplex mode, which can severely degrade network performance and cause packet loss. | No | 2025-06-26 |
| Networking | NIC link down while connected to switch | High | Flags NICs that are connected to a switch but have no link, indicating possible cable or switch port issues. | Yes | 2025-06-26 |
| Networking | VMkernel IP bound to down NIC | Critical | Detects vmkernel interfaces assigned to NICs that are down, risking loss of management, vMotion, or storage connectivity. | Yes | 2025-06-26 |
| Networking | VMkernel IP bound to sub-10Gb NIC | Medium | Flags vmkernel interfaces assigned to NICs below 10Gbps, potentially limiting vMotion or storage performance. | Yes | 2025-06-26 |
| Networking | VMkernel MTU mismatch | High | Identifies mismatched MTU settings on vmkernel interfaces, which can cause packet drops or performance issues. | Yes | 2025-06-26 |
| Networking | VMkernel subnet mask mismatch | High | Detects inconsistent subnet masks on vmkernel interfaces within a cluster, leading to unpredictable routing and connectivity problems. | Yes | 2025-06-26 |
| RDM | RDM disk in use | Info | Identifies VMs using Raw Device Mapping (RDM) disks, which may complicate backup, replication, or migration operations. | No | 2025-06-26 |
| Resource Pool | CPU limit set | Medium | Detects resource pools with CPU limits, which can throttle VM performance regardless of available cluster resources. | No | 2025-06-26 |
| Resource Pool | CPU reservation at limit | High | Flags resource pools where CPU reservations are set at the pool’s limit, risking resource contention and admission control failures. | No | 2025-06-26 |
| Resource Pool | CPU reservation near limit | Medium | Warns when CPU reservations approach the resource pool’s limit, indicating potential for resource denial to new or existing VMs. | No | 2025-06-26 |
| Resource Pool | Excessive VMs in resource pool | Medium | Identifies resource pools containing an unusually high number of VMs, which may complicate management or cause resource contention. | No | 2025-06-26 |
| Resource Pool | Memory limit set | Medium | Detects resource pools with memory limits, which can restrict VM memory allocation and impact performance. | No | 2025-06-26 |
| Resource Pool | Memory reservation at limit | High | Flags resource pools where memory reservations are set at the pool’s limit, risking resource contention and admission control failures. | No | 2025-06-26 |
| Resource Pool | Memory reservation near limit | Medium | Warns when memory reservations approach the resource pool’s limit, indicating potential for resource denial to new or existing VMs. | No | 2025-06-26 |
| Resource Pool | ResourcePool CPU reservation >> usage | Low | Identifies resource pools with CPU reservations significantly exceeding actual usage, which may waste resources and reduce cluster efficiency. | No | 2025-06-26 |
| Resource Pool | ResourcePool Mem reservation >> usage | Low | Identifies resource pools with memory reservations significantly exceeding actual usage, which may waste resources and reduce cluster efficiency. | No | 2025-06-26 |
| SRM | SRM Placeholder VM Found |   | Detects the presence of Site Recovery Manager (SRM) Placeholder VMs, which are expected in DR environments but should not be powered on or modified. | No | 2025-06-26 |
| Storage | Datastore not on all hosts | Medium | Flags datastores that are not accessible by all hosts in a cluster, which can block VM mobility and HA failover. | Yes | 2025-06-26 |
| Storage | Datastore with >=2 active paths | Info | Confirms datastores with two or more active paths, providing redundancy and improved storage availability. | No | 2025-06-26 |
| Storage | Datastore with no active path to at least 1 host in cluster | High | Detects datastores that are inaccessible to at least one host, risking VM outages and reducing HA effectiveness. | No | 2025-06-26 |
| Storage | Datastore with non-uniform number of paths per host in cluster | Low | Identifies datastores with an inconsistent number of active paths across hosts, which may indicate misconfiguration or hardware issues. | No | 2025-06-26 |
| Storage | Datastore with single active path to at least 1 host in cluster | High | Flags datastores with only one active path to a host, creating a single point of failure for storage access. | No | 2025-06-26 |
| Storage | Inconsistent path count across hosts | Medium | Detects inconsistencies in storage path counts between hosts, which can impact redundancy and performance. | No | 2025-06-26 |
| Storage | NFS free space < 10% | High | Warns when NFS datastore free space drops below 10%, increasing risk of VM failures or inability to create snapshots. | No | 2025-06-26 |
| Storage | NFS free space < 20% | Medium | Warns when NFS datastore free space drops below 20%, signaling the need for capacity planning. | No | 2025-06-26 |
| Storage | NFS free space < 5% | Critical | Alerts when NFS datastore free space drops below 5%, posing immediate risk to VM operations. | No | 2025-06-26 |
| Storage | VM(s) on local-only datastore | Medium | Identifies VMs residing on datastores local to a single host, which prevents vMotion and HA failover. | Yes | 2025-06-26 |
| Storage | VMFS free space < 10% | High | Warns when VMFS datastore free space drops below 10%, increasing risk of VM failures or inability to create snapshots. | No | 2025-06-26 |
| Storage | VMFS free space < 20% | Medium | Warns when VMFS datastore free space drops below 20%, signaling the need for capacity planning. | No | 2025-06-26 |
| Storage | VMFS free space < 5% | Critical | Alerts when VMFS datastore free space drops below 5%, posing immediate risk to VM operations. | No | 2025-06-26 |
| Storage | vSAN free space < 10% | Critical | Warns when vSAN free space drops below 10%, risking VM provisioning failures and degraded performance. | No | 2025-06-26 |
| Storage | vSAN free space < 25% | High | Warns when vSAN free space drops below 25%, signaling the need for capacity management and risk of reduced cluster resilience. | No | 2025-06-26 |
| VCD | Org VDC Allocation Model Detected | Info | Identifies the allocation model used by Organization VDCs, which impacts resource consumption, overcommitment, and operational flexibility in vCloud Director. | No | 2025-06-26 |
| VCD | VCD Org VDCs Detected | Info | Detects the presence of Organization VDCs in vCloud Director, which may require special management or monitoring. | No | 2025-06-26 |
| VCF | Host under 16-core VCF licensing rule | Info | Flags hosts subject to the 16-core licensing rule for VMware Cloud Foundation, which may impact license compliance and cost planning. | No | 2025-06-26 |
| VM | VM HW version not compatible with all hosts in cluster | Medium | Identifies VMs with hardware versions that are incompatible with some hosts, risking vMotion failures and limiting maintenance flexibility. | No | 2025-06-26 |
| VM CPU | Memory Hot-Add enabled | Low | Identifies VMs with memory hot-add enabled, which can impact performance or licensing if not managed properly. | No | 2025-06-26 |
| VM CPU | VM memory exceeds single NUMA node | Medium | Flags VMs whose memory allocation exceeds a single NUMA node, potentially causing suboptimal performance due to memory locality issues. | No | 2025-06-26 |
| VM CPU | VM socket count exceeds host socket count | Medium | Detects VMs configured with more CPU sockets than are physically available on hosts. The detail includes the VM's hardware version. | No | 2025-06-26 |
| VM CPU | VM socket count exceeds host socket count (Check) | Low | Flags VMs with hardware version 20 or newer where socket count exceeds host sockets. The detail includes the VM's hardware version. Ensure CPU Topology is set to 'Assigned on Power On'. | No | 2025-06-26 |
| VM CPU | vCPU Hot-Add enabled | Low | Detects VMs with vCPU hot-add enabled, which may impact performance or licensing if not required. | No | 2025-06-26 |
| VM CPU | vCPU Hot-Remove enabled | Low | Detects VMs with vCPU hot-remove enabled, which may impact performance or licensing if not required. | No | 2025-06-26 |
| VM CPU | vCPU count exceeds host total cores | High | Flags VMs configured with more vCPUs than the total physical cores available on hosts, risking scheduling delays and poor performance. | No | 2025-06-26 |
| VM CPU | vCPU reservation set | Low | Identifies VMs with CPU reservations, which may impact cluster resource allocation and admission control. | No | 2025-06-26 |
| VM CPU | vCores per socket exceeds host NUMA node | Medium | Flags VMs with more vCPUs per socket than the host’s NUMA node supports, risking performance degradation. | No | 2025-06-26 |
| VM EVC | VM HW version exceeds cluster compatibility | Medium | Warns that a VM’s hardware version is newer than what the cluster supports, risking vMotion or startup failures. | No | 2025-06-26 |
| VM Hygiene | Orphaned VM | High | Identifies orphaned VMs, which are no longer associated with a registered host and may consume resources unnecessarily. | No | 2025-06-26 |
| VM Hygiene | Unknown/stale VM power state | Medium | Flags VMs with unknown or stale power states, which can complicate management and automation. | No | 2025-06-26 |
| VM Hygiene | VM disconnected/inaccessible | Medium | Detects VMs that are disconnected or inaccessible, potentially indicating storage, network, or configuration issues. | No | 2025-06-26 |
| VM Hygiene | VM missing annotation | Info | Identifies VMs lacking annotations, which may hinder documentation and operational clarity. | No | 2025-06-26 |
| VM Hygiene | VMware Tools not installed | Medium | Flags VMs without VMware Tools installed, limiting manageability and feature availability. | No | 2025-06-26 |
| VM Hygiene | VMware Tools not running | Medium | Detects VMs where VMware Tools is not running, risking loss of integration features and monitoring capabilities. | No | 2025-06-26 |
| VM Hygiene | VMware Tools outdated | Medium | Identifies VMs with outdated VMware Tools, which may lack security patches and new features. | No | 2025-06-26 |
| VM Memory | Memory ballooning active | Medium | Flags VMs experiencing memory ballooning, indicating host memory pressure and potential performance impact. | No | 2025-06-26 |
| VM Memory | Memory reservation below full allocation | Info | Identifies VMs with memory reservations set below their full allocation, risking performance issues during host contention. | No | 2025-06-26 |
| VM Memory | Memory reservation set | Low | Detects VMs with memory reservations, which can impact resource allocation and admission control. | No | 2025-06-26 |
| VM Memory | Memory swap present | Medium | Identifies VMs that have swapped memory to disk, indicating host memory contention and degraded performance. | No | 2025-06-26 |
| VM Memory | Possible swap root cause | Info | Provides potential causes for VM memory swapping, assisting in troubleshooting and remediation. | No | 2025-06-26 |
| VM Mobility EVC | VM stuck on newer CPU in non-EVC cluster | High | Warns that a VM is running on a host with a newer CPU in a cluster without EVC, preventing migration to older hosts and risking availability. | Yes | 2025-06-26 |
| VM Security | Guest OS supports EFI but VM is BIOS | Low | Identifies VMs where the guest OS supports EFI but the VM is configured for BIOS, potentially missing security and boot features. | No | 2025-06-26 |
| VM Security | Secure Boot disabled | Low | Flags VMs with Secure Boot disabled, increasing risk of boot-level malware or rootkit attacks. | No | 2025-06-26 |
| VM Security | Secure Boot status unknown | Info | Detects VMs where Secure Boot status cannot be determined, complicating compliance and security assessments. | No | 2025-06-26 |
| VM Security | VM set to EFI but guest may not support it | Medium | Warns that a VM is configured for EFI firmware while the guest OS may not support it, risking boot failures. | No | 2025-06-26 |
| VM Security | VM uses legacy BIOS | Low | Identifies VMs using legacy BIOS firmware, which may lack modern security and compatibility features. | No | 2025-06-26 |
| VM Storage | Snapshot chain > 3 | Medium | Flags VMs with more than three snapshots, which can degrade performance and complicate backup or recovery. | No | 2025-06-26 |
| VM Storage | Snapshot consolidation required | Critical | Detects VMs requiring snapshot consolidation, which if left unresolved can risk data integrity and backup failures. | No | 2025-06-26 |
| dvSwitch | Host member missing | Low | Identifies distributed switches missing expected host members, risking network connectivity issues for VMs or vmkernel interfaces. | No | 2025-06-26 |
| dvSwitch | Legacy dvSwitch version blocks ESXi 8.0 upgrade | High | Flags distributed switches running legacy versions incompatible with ESXi 8.0, which must be upgraded before host upgrades. | Yes | 2025-06-26 |
| dvSwitch | Unknown dvSwitch version | Low | Detects distributed switches with unknown version numbers, complicating compatibility and upgrade planning. | No | 2025-06-26 |
| dvSwitch | Unparsable version string | Info | Flags distributed switches with unparsable version strings, which may indicate corruption or unsupported configurations. | No | 2025-06-26 |
| dvSwitch | dvSwitch at latest version | Info | Confirms distributed switches are at the latest supported version, maximizing feature availability and compatibility. | No | 2025-06-26 |
| dvSwitch | dvSwitch upgrade available | Medium | Identifies distributed switches with available upgrades, enabling access to new features and improved compatibility. | No | 2025-06-26 |
| vCenter | Invalid vCenter label format | High | Detects vCenter objects with invalid label formats, which may complicate automation or reporting. | No | 2025-06-26 |
| vCenter | Unknown vCenter build | High | Flags vCenters with unrecognized build numbers, making supportability and patching status unclear. | No | 2025-06-26 |
| Cluster | DNS server list order mismatch | Low | DNS server list order differs between hosts; may cause inconsistent resolution. | No | 2025-06-26 |
| Cluster | Inconsistent BIOS Date | Medium | Hosts in cluster report differing BIOS dates, indicating inconsistent firmware. | No | 2025-06-26 |
| Cluster | Inconsistent host domain names | High | Hosts have different domain names configured, complicating DNS and SSO. | Yes | 2025-06-26 |
| Cluster | Mixed server models | Info | Cluster contains different server models which may hinder uniform updates. | No | 2025-06-26 |
| Cluster Compatibility | VMHW exceeds compatibility of oldest host in cluster | Low | VM hardware version newer than oldest host supports; vMotion may fail. | No | 2025-06-26 |
| Host Config | Host missing domain name | High | Host has no domain name set, which can impact DNS resolution. | No | 2025-06-26 |
| Host Performance | Host memory allocation over 90% | High | Host memory usage exceeds 90% of physical capacity. | No | 2025-06-26 |
| VM CPU | VM using multiple vCPU sockets (Optimal) | Info | VM configured with multiple vCPU sockets when optimal for host. | No | 2025-06-26 |
| vCenter | Unsupported ESXi version | High | vCenter version cannot manage some connected ESXi hosts. | No | 2025-06-26 |
| vCenter | Unsupported vCenter major | High | vCenter major version not supported by rule set. | No | 2025-06-26 |
| VM Storage | Snapshot >X days old | High | Flags snapshots older than the configured retention threshold. | No | 2025-06-26 |
| vCenter | Fully patched | Info | Reports vCenter build is up-to-date with the latest available patch. | No | 2025-06-26 |

**Disclaimer:** Findings should be reviewed in the context of your environment. Some results may be acceptable depending on operational requirements. No warranty or accuracy is provided. Feel free to suggest additional tests or improvements.
