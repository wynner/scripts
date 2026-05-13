resource "vcfa_content_library" "application" {
  org_id      = vcfa_org.tenant.id
  name        = var.application.content_library_name
  description = coalesce(var.application.content_library_description, "${var.tenant.display_name} application content library")

  storage_class_ids = [
    for storage_class in data.vcfa_storage_class.library : storage_class.id
  ]

  depends_on = [
    vcfa_org_region_quota.tenant
  ]
}

# The VCD demo uploaded templates and created empty VMs, disks, NAT, and firewall
# rules. The current VCFA Terraform provider covers the tenant library, but not
# those workload and edge-security resources as first-class Terraform resources.
