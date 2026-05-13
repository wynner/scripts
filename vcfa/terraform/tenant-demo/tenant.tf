resource "vcfa_org" "tenant" {
  name         = var.tenant.name
  display_name = var.tenant.display_name
  description  = coalesce(var.tenant.description, "${var.tenant.display_name} Terraform demo tenant")
  is_enabled   = true
}

resource "vcfa_org_region_quota" "tenant" {
  org_id         = vcfa_org.tenant.id
  region_id      = data.vcfa_region.tenant.id
  supervisor_ids = [data.vcfa_supervisor.tenant.id]

  zone_resource_allocations {
    region_zone_id         = data.vcfa_region_zone.tenant.id
    cpu_limit_mhz          = var.region_quota.cpu_limit_mhz
    cpu_reservation_mhz    = var.region_quota.cpu_reservation_mhz
    memory_limit_mib       = var.region_quota.memory_limit_mib
    memory_reservation_mib = var.region_quota.memory_reservation_mib
  }

  region_vm_class_ids = [
    for vm_class in data.vcfa_region_vm_class.tenant : vm_class.id
  ]

  dynamic "region_storage_policy" {
    for_each = var.region_quota.storage_policies
    content {
      region_storage_policy_id = data.vcfa_region_storage_policy.tenant[region_storage_policy.key].id
      storage_limit_mib        = region_storage_policy.value.limit_mib
    }
  }
}

resource "vcfa_org_networking" "tenant" {
  org_id   = vcfa_org.tenant.id
  log_name = var.tenant.networking_log_name
}

resource "vcfa_org_regional_networking" "tenant" {
  name                = var.tenant.regional_network_name
  org_id              = vcfa_org_networking.tenant.id
  region_id           = data.vcfa_region.tenant.id
  provider_gateway_id = data.vcfa_provider_gateway.tenant.id
  edge_cluster_id     = data.vcfa_edge_cluster.tenant.id
}

resource "vcfa_org_local_user" "admin" {
  org_id   = vcfa_org.tenant.id
  role_ids = [data.vcfa_role.org_admin.id]
  username = var.tenant.admin_username
  password = var.tenant_admin_password
}
