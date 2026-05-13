# VCD Tenant Demo

This Terraform example extends the base VMware Cloud Director tenant
demo with tenant operations and security-policy objects.

## Safety Warning

Use these scripts with care. They create, change, and destroy infrastructure
objects, so test them only in non-production test environments unless you have
reviewed and adapted the code for your own platform.

It creates:

- A tenant organization and Flex organization VDC.
- An NSX-T edge gateway and routed organization network.
- An initial tenant organization administrator.
- A tenant catalog library.
- A catalog library. The OVA upload is commented out in this variant.
- A shared VCD Named Disk.
- Two empty dummy database VMs attached to the routed network.
- Per-VM NVMe internal boot disks on the `Performance` storage profile.
- A demo VM security group, security tag, SSH DNAT rules, and an NSX-T edge
  firewall rule.
- LDAP-backed tenant user imports.
- Tenant IP sets for admin sources, DNS, and NTP services.
- Tenant-scoped application port profiles for DNS, NTP, and HTTPS.
- Outbound SNAT for the routed tenant subnet.
- A richer ordered edge firewall policy.
- Metadata on major tenant resources.

This is from a larger example that is derived from a demo focused
on VCD resources only and removes the end ot end automation
including NSX, phpIPAM, UniFi, and AVi.

## Files

- `tenant.tf` builds the tenant foundation.
- `application.tf` builds the catalog, template, Named Disk, VM pair, NAT,
  IP sets, app port profiles, security group, and firewall policy.
- `data.tf` looks up provider-side objects that must already exist.
- `terraform.tfvars.example` shows the expected inputs.

## Before Applying

Confirm these provider-side values in the target VCD instance:

- Provider VDC display name.
- Network pool display name.
- Provider Gateway or external network display name.
- IP Space display name for SSH DNAT floating IP allocation.
- Edge cluster display name.
- VM sizing policy display name.
- Storage policy display name.
- LDAP provider configuration on the tenant organization if
  `tenant_ldap_users` is not empty. External users are imported with
  `is_external = true`; no LDAP passwords are stored in Terraform.

Use textual names exactly as they appear in VCD, not UUIDs or URNs. The
Terraform code uses data sources to look up IDs from these names at plan/apply
time:

- `data.vcd_provider_vdc.provider` looks up `var.provider_vdc_name`.
- `data.vcd_external_network_v2.external` looks up
  `var.provider_gateway_name`.
- `data.vcd_ip_space.external` looks up `var.ip_space_name`.
- `data.vcd_nsxt_edge_cluster.edge_cluster` looks up
  `var.edge_cluster_name` within the selected Provider VDC.
- `data.vcd_vm_sizing_policy.application` looks up
  `var.vm_sizing_policy_name`.
- `data.vcd_storage_profile.catalog` looks up the default storage policy from
  `var.storage_profiles`.

The variables above validate that the input is not a UUID or URN, so users get
an early error if they paste an internal ID instead of a VCD display name.

Do not commit `terraform.tfvars`, `*.auto.tfvars`, `.terraform/`, state files,
or plan files. They are ignored by `.gitignore`; publish only the example
configuration and `terraform.tfvars.example`.

In this tenant demo the VMs are empty dummy machines named `db01` and `db02`.
Each VM is configured for 1 vCPU, 1 GiB RAM, VM hardware `vmx-19`, and a 10 GiB
NVMe internal disk on `Performance`.

## Commands

```sh
terraform init
terraform fmt
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

The VM resources are intentionally split into a primary VM and a secondary VM.
The secondary VM depends on the primary VM, so the shared Named Disk is attached
to one VM and then the other. That keeps the VCD shared-disk operation
serialized while allowing unrelated resources to use Terraform's normal
parallelism.

If your VCD/vCenter combination rejects adding the NVMe internal disks while
the VMs are powered on, run the first apply with `application.power_on=false`,
then set `application.power_on=true` and apply again. That keeps the disk
creation and final power-on as Terraform-managed changes.

For teardown against VCD 39.1, disable the Org VDC with Terraform before
`terraform destroy`. The provider can remove a disabled VDC cleanly, but VCD
rejects deletion while the VDC is enabled.

```sh
terraform apply -target=vcd_org_vdc.tenant -var tenant_vdc_enabled=false
terraform destroy
```

## Advanced Demo Elements

- `tenant_ldap_users` imports LDAP-backed users and assigns VCD roles.
- `vcd_nsxt_ip_set` models reusable firewall groups such as
  `trusted-admin-sources`, `lab-dns`, and `lab-ntp`.
- Tenant-scoped `vcd_nsxt_app_port_profile` resources demonstrate custom
  service definitions for DNS, NTP, and HTTPS.
- `tenant-outbound-snat` shows edge NAT as code for workload egress.
- The edge firewall policy demonstrates ordered rules: allow SSH from trusted
  sources, allow DNS/NTP/HTTPS egress from the demo VM security group, then
  drop other inbound traffic to that group.
