# VCFA Tenant Demo Partial

This Terraform example partially recreates the VMware Cloud Director tenant demo in a
another directory, this time in VMware Cloud Foundation Automation.

## Safety Warning

Use these scripts with care. They create, change, and destroy infrastructure
objects, so test them only in non-production test environments unless you have
reviewed and adapted the code for your own platform.

The demo creates the VCFA-native elements that maps cleanly from the VCD
demo. All environment-specific names and quotas live in variables, with example
values in `terraform.tfvars.example`:

- Tenant organization `demo-tf`.
- Region quota on a named region and region zone.
- VM class allow-list using example `standard-*` classes.
- Storage policy quota for `Standard` and `Performance`.
- Organization networking settings and regional networking through
  `pgw-vcf-res` and `vcf-res-edge-cluster`.
- A local tenant administrator.
- A tenant content library.

The current VCFA Terraform provider does not expose first-class equivalents for
the VCD demo's standalone VMs, independent disks, internal VM disks, routed Org
VDC networks, edge NAT rules, edge firewall policies, tenant NSX-T IP sets,
tenant security groups, app port profiles, or security tags. Those would need a
separate set of scripts that go beyonf the VCFA 1.0 terraform provider.

## Example Values

The checked-in example values are placeholders and should be changed for your
VCFA environment:

| Setting | Value |
| --- | --- |
| Endpoint | `https://vcfa.domain.com` |
| Region | `example-region` |
| Region zone | `example-zone` |
| vCenter | `vcenter.domain.com` |
| Supervisor | `example-supervisor` |
| Provider gateway | `example-provider-gateway` |
| Edge cluster | `example-edge-cluster` |
| Storage policies/classes | `Standard`, `Performance` |
| Suggested VM classes | `standard-nano`, `standard-micro`, `standard-small` |

## Usage

Copy the example variables file and fill in the values for your environment:

```sh
cp terraform.tfvars.example terraform.tfvars
```

Edit the copied file with the values in your VCFA environment.

Then run Terraform:

```sh
terraform init
terraform fmt
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```
