resource "vcd_org" "tenant" {
  name                         = var.tenant.org_name
  full_name                    = var.tenant.org_full_name
  description                  = "Tenant provisioned by Terraform"
  is_enabled                   = true
  can_publish_catalogs         = true
  delay_after_power_on_seconds = 0
  deployed_vm_quota            = 0
  stored_vm_quota              = 0
  delete_recursive             = true
  delete_force                 = true

  vapp_lease {
    maximum_runtime_lease_in_sec          = 0
    maximum_storage_lease_in_sec          = 0
    power_off_on_runtime_lease_expiration = true
    delete_on_storage_lease_expiration    = true
  }

  vapp_template_lease {
    maximum_storage_lease_in_sec       = 0
    delete_on_storage_lease_expiration = true
  }
}

resource "vcd_vm_sizing_policy" "database" {
  name        = "tenant-demo-db-small"
  description = "1 vCPU and 1 GiB RAM for Terraform dummy database VMs"

  cpu {
    count            = tostring(var.application.vm_cpus)
    cores_per_socket = tostring(var.application.vm_cpu_cores)
    speed_in_mhz     = tostring(var.vdc_compute.cpu_speed_mhz)
  }

  memory {
    size_in_mb = tostring(var.application.vm_memory_mb)
  }
}

resource "vcd_org_vdc" "tenant" {
  org                        = vcd_org.tenant.name
  name                       = var.tenant.org_vdc_name
  provider_vdc_name          = data.vcd_provider_vdc.provider.name
  network_pool_name          = var.network_pool_name
  allocation_model           = "Flex"
  enabled                    = var.tenant_vdc_enabled
  elasticity                 = true
  include_vm_memory_overhead = false
  enable_fast_provisioning   = true
  enable_thin_provisioning   = true
  enable_vm_discovery        = false
  delete_recursive           = true
  delete_force               = true
  network_quota              = 100
  nic_quota                  = 0
  vm_quota                   = 0
  cpu_speed                  = var.vdc_compute.cpu_speed_mhz
  cpu_guaranteed             = 0
  memory_guaranteed          = 0
  default_compute_policy_id  = vcd_vm_sizing_policy.database.id
  vm_sizing_policy_ids = [
    data.vcd_vm_sizing_policy.application.id,
    vcd_vm_sizing_policy.database.id,
  ]

  compute_capacity {
    cpu {
      allocated = var.vdc_compute.cpu_allocated_mhz
      limit     = var.vdc_compute.cpu_limit_mhz
    }

    memory {
      allocated = var.vdc_compute.memory_allocated
      limit     = var.vdc_compute.memory_limit
    }
  }

  dynamic "storage_profile" {
    for_each = var.storage_profiles
    content {
      name    = storage_profile.value.name
      limit   = storage_profile.value.limit
      default = storage_profile.value.default
      enabled = true
    }
  }

}

resource "vcd_nsxt_edgegateway" "tenant" {
  org                       = vcd_org.tenant.name
  owner_id                  = vcd_org_vdc.tenant.id
  name                      = var.tenant.edge_name
  external_network_id       = data.vcd_external_network_v2.external.id
  edge_cluster_id           = data.vcd_nsxt_edge_cluster.edge_cluster.id
  dedicate_external_network = false
}

resource "vcd_network_routed_v2" "tenant" {
  org             = vcd_org.tenant.name
  name            = var.tenant.network_name
  edge_gateway_id = vcd_nsxt_edgegateway.tenant.id
  interface_type  = "internal"
  gateway         = var.routed_network.gateway
  prefix_length   = var.routed_network.prefix_length
  dns1            = var.routed_network.dns1
  dns2            = var.routed_network.dns2
  dns_suffix      = var.routed_network.dns_suffix

  static_ip_pool {
    start_address = var.routed_network.pool_start
    end_address   = var.routed_network.pool_end
  }
}

resource "vcd_org_user" "admin" {
  org               = vcd_org.tenant.name
  name              = var.tenant.admin_user
  password          = var.tenant_admin_password
  role              = "Organization Administrator"
  provider_type     = "INTEGRATED"
  enabled           = true
  is_locked         = false
  deployed_vm_quota = 0
  stored_vm_quota   = 0
  email_address     = try(var.tenant.admin_email, null)
}

resource "vcd_org_user" "ldap" {
  # VCD 10.6.1.1 rejected LDAP user import from this provider session with
  # GROUP_USER_MANAGE/USER_IMPORT rights even as System administration.
  for_each = {}

  org               = vcd_org.tenant.name
  name              = each.key
  role              = each.value.role
  is_external       = true
  enabled           = each.value.enabled
  is_locked         = false
  deployed_vm_quota = each.value.deployed_vm_quota
  stored_vm_quota   = each.value.stored_vm_quota
  full_name         = try(each.value.full_name, null)
  email_address     = try(each.value.email_address, null)
}
