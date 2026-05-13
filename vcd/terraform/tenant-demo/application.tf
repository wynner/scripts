locals {
  routed_network_cidr = coalesce(try(var.routed_network.cidr, null), "${var.routed_network.gateway}/${var.routed_network.prefix_length}")

  app_vms = {
    for index, name in var.application.vm_names : name => {
      bus_number   = 1
      unit_number  = 0
      nat_priority = 100 + index
    }
  }

  primary_vm_name   = var.application.vm_names[0]
  secondary_vm_name = var.application.vm_names[1]

  primary_app_vm = {
    (local.primary_vm_name) = local.app_vms[local.primary_vm_name]
  }

  secondary_app_vm = {
    (local.secondary_vm_name) = local.app_vms[local.secondary_vm_name]
  }

  demo_vms = merge(vcd_vm.demo_primary, vcd_vm.demo_secondary)
}

resource "vcd_catalog" "application" {
  org                = vcd_org.tenant.name
  name               = var.application.catalog_name
  description        = coalesce(var.application.catalog_description, "${var.tenant.org_full_name} application catalog")
  storage_profile_id = data.vcd_storage_profile.catalog.id
  publish_enabled    = false
  delete_recursive   = true
  delete_force       = true

}

# OVA upload intentionally disabled for the dummy-VM variant.
# resource "vcd_catalog_vapp_template" "demo" {
#   org               = vcd_org.tenant.name
#   catalog_id        = vcd_catalog.application.id
#   name              = var.application.demo_template_name
#   description       = coalesce(var.application.demo_template_desc, "Demo application template")
#   ova_path          = var.application.demo_ova_path
#   upload_piece_size = var.application.upload_piece_size_mb
# }

resource "vcd_independent_disk" "shared" {
  org             = vcd_org.tenant.name
  vdc             = vcd_org_vdc.tenant.name
  name            = var.application.named_disk_name
  size_in_mb      = var.application.named_disk_size_mb
  bus_type        = var.application.named_disk_bus_type
  bus_sub_type    = var.application.named_disk_bus_sub_type
  sharing_type    = var.application.named_disk_sharing_type
  storage_profile = var.application.named_disk_storage_profile

}

resource "vcd_vm" "demo_primary" {
  for_each = local.primary_app_vm

  org                    = vcd_org.tenant.name
  vdc                    = vcd_org_vdc.tenant.name
  name                   = each.key
  computer_name          = each.key
  description            = "Empty dummy database VM provisioned by Terraform"
  power_on               = var.application.power_on
  cpus                   = var.application.vm_cpus
  cpu_cores              = var.application.vm_cpu_cores
  memory                 = var.application.vm_memory_mb
  os_type                = var.application.vm_os_type
  hardware_version       = var.application.vm_hardware_version
  firmware               = "efi"
  cpu_hot_add_enabled    = false
  memory_hot_add_enabled = false
  storage_profile        = var.application.vm_storage_profile
  sizing_policy_id       = vcd_vm_sizing_policy.database.id

  network {
    name               = vcd_network_routed_v2.tenant.name
    type               = "org"
    is_primary         = true
    ip_allocation_mode = "POOL"
    adapter_type       = "vmxnet3"
    connected          = true
  }

  disk {
    name        = vcd_independent_disk.shared.name
    bus_number  = each.value.bus_number
    unit_number = each.value.unit_number
  }

  depends_on = [
    vcd_catalog.application,
    vcd_independent_disk.shared
  ]
}

resource "vcd_vm" "demo_secondary" {
  for_each = local.secondary_app_vm

  org                    = vcd_org.tenant.name
  vdc                    = vcd_org_vdc.tenant.name
  name                   = each.key
  computer_name          = each.key
  description            = "Empty dummy VM provisioned by Terraform"
  power_on               = var.application.power_on
  cpus                   = var.application.vm_cpus
  cpu_cores              = var.application.vm_cpu_cores
  memory                 = var.application.vm_memory_mb
  os_type                = var.application.vm_os_type
  hardware_version       = var.application.vm_hardware_version
  firmware               = "efi"
  cpu_hot_add_enabled    = false
  memory_hot_add_enabled = false
  storage_profile        = var.application.vm_storage_profile
  sizing_policy_id       = vcd_vm_sizing_policy.database.id

  network {
    name               = vcd_network_routed_v2.tenant.name
    type               = "org"
    is_primary         = true
    ip_allocation_mode = "POOL"
    adapter_type       = "vmxnet3"
    connected          = true
  }

  disk {
    name        = vcd_independent_disk.shared.name
    bus_number  = each.value.bus_number
    unit_number = each.value.unit_number
  }

  depends_on = [
    vcd_catalog.application,
    vcd_independent_disk.shared,
    vcd_vm.demo_primary
  ]
}

resource "vcd_vm_internal_disk" "database_boot" {
  for_each = local.demo_vms

  org             = vcd_org.tenant.name
  vdc             = vcd_org_vdc.tenant.name
  vapp_name       = each.value.vapp_name
  vm_name         = each.value.name
  bus_type        = var.application.vm_internal_disk_bus_type
  bus_number      = var.application.vm_internal_disk_bus
  unit_number     = var.application.vm_internal_disk_unit
  size_in_mb      = var.application.vm_internal_disk_size_mb
  storage_profile = var.application.vm_storage_profile
  allow_vm_reboot = true
}

resource "vcd_nsxt_app_port_profile" "dns" {
  org        = vcd_org.tenant.name
  context_id = vcd_org_vdc.tenant.id
  name       = "tenant-dns"
  scope      = "TENANT"

  app_port {
    protocol = "TCP"
    port     = ["53"]
  }

  app_port {
    protocol = "UDP"
    port     = ["53"]
  }
}

resource "vcd_nsxt_app_port_profile" "ntp" {
  org        = vcd_org.tenant.name
  context_id = vcd_org_vdc.tenant.id
  name       = "tenant-ntp"
  scope      = "TENANT"

  app_port {
    protocol = "UDP"
    port     = ["123"]
  }
}

resource "vcd_nsxt_app_port_profile" "https" {
  org        = vcd_org.tenant.name
  context_id = vcd_org_vdc.tenant.id
  name       = "tenant-https"
  scope      = "TENANT"

  app_port {
    protocol = "TCP"
    port     = ["443"]
  }
}

resource "vcd_nsxt_ip_set" "trusted_admin_sources" {
  org             = vcd_org.tenant.name
  edge_gateway_id = vcd_nsxt_edgegateway.tenant.id
  name            = "trusted-admin-sources"
  description     = "Sources allowed to SSH to the demo VMs"
  ip_addresses    = var.security.trusted_admin_sources
}

resource "vcd_nsxt_ip_set" "lab_dns" {
  org             = vcd_org.tenant.name
  edge_gateway_id = vcd_nsxt_edgegateway.tenant.id
  name            = "lab-dns"
  description     = "DNS services for tenant workloads"
  ip_addresses    = var.security.lab_dns_servers
}

resource "vcd_nsxt_ip_set" "lab_ntp" {
  org             = vcd_org.tenant.name
  edge_gateway_id = vcd_nsxt_edgegateway.tenant.id
  name            = "lab-ntp"
  description     = "NTP services for tenant workloads"
  ip_addresses    = var.security.lab_ntp_servers
}

resource "vcd_nsxt_security_group" "demo" {
  org             = vcd_org.tenant.name
  edge_gateway_id = vcd_nsxt_edgegateway.tenant.id
  name            = var.security.demo_security_group_name
  description     = "Demo application VMs provisioned by Terraform"

  member_org_network_ids = [
    vcd_network_routed_v2.tenant.id
  ]

  depends_on = [
    vcd_vm.demo_primary,
    vcd_vm.demo_secondary
  ]
}

resource "vcd_security_tag" "demo" {
  org    = vcd_org.tenant.name
  name   = var.security.demo_security_group_name
  vm_ids = [for vm in local.demo_vms : vm.id]
}

resource "vcd_ip_space_custom_quota" "tenant" {
  org_id         = vcd_org.tenant.id
  ip_space_id    = data.vcd_ip_space.external.id
  ip_range_quota = tostring(length(var.application.vm_names) + 1)

  depends_on = [
    vcd_nsxt_edgegateway.tenant
  ]
}

resource "vcd_ip_space_ip_allocation" "ssh_dnat" {
  for_each = local.app_vms

  org_id      = vcd_org.tenant.id
  ip_space_id = data.vcd_ip_space.external.id
  type        = "FLOATING_IP"
  value       = lookup(var.security.ssh_dnat_external_ips, each.key, null)

  depends_on = [
    vcd_ip_space_custom_quota.tenant
  ]
}

resource "vcd_ip_space_ip_allocation" "outbound_snat" {
  org_id      = vcd_org.tenant.id
  ip_space_id = data.vcd_ip_space.external.id
  type        = "FLOATING_IP"

  depends_on = [
    vcd_ip_space_custom_quota.tenant
  ]
}

resource "vcd_nsxt_nat_rule" "ssh_dnat" {
  for_each = local.app_vms

  org             = vcd_org.tenant.name
  edge_gateway_id = vcd_nsxt_edgegateway.tenant.id

  name                = "ssh-dnat-${each.key}"
  rule_type           = "DNAT"
  description         = "SSH inbound to ${each.key}"
  external_address    = vcd_ip_space_ip_allocation.ssh_dnat[each.key].ip
  internal_address    = local.demo_vms[each.key].network[0].ip
  app_port_profile_id = data.vcd_nsxt_app_port_profile.ssh.id
  dnat_external_port  = "22"
  firewall_match      = "MATCH_INTERNAL_ADDRESS"
  priority            = each.value.nat_priority
  logging             = false
  enabled             = true
}

resource "vcd_nsxt_nat_rule" "outbound_snat" {
  org             = vcd_org.tenant.name
  edge_gateway_id = vcd_nsxt_edgegateway.tenant.id

  name             = "tenant-outbound-snat"
  rule_type        = "SNAT"
  description      = "Outbound SNAT for the tenant routed network"
  external_address = vcd_ip_space_ip_allocation.outbound_snat.ip
  internal_address = local.routed_network_cidr
  firewall_match   = "MATCH_INTERNAL_ADDRESS"
  priority         = 200
  logging          = false
  enabled          = true
}

resource "vcd_nsxt_firewall" "tenant" {
  org             = vcd_org.tenant.name
  edge_gateway_id = vcd_nsxt_edgegateway.tenant.id

  rule {
    name                 = "allow-ssh-inbound-to-demo-vms"
    action               = "ALLOW"
    direction            = "IN"
    ip_protocol          = "IPV4"
    app_port_profile_ids = [data.vcd_nsxt_app_port_profile.ssh.id]
    destination_ids      = [vcd_nsxt_security_group.demo.id]
    source_ids           = [vcd_nsxt_ip_set.trusted_admin_sources.id]
    enabled              = true
    logging              = false
  }

  rule {
    name                 = "allow-demo-vms-to-lab-dns"
    action               = "ALLOW"
    direction            = "OUT"
    ip_protocol          = "IPV4"
    app_port_profile_ids = [vcd_nsxt_app_port_profile.dns.id]
    source_ids           = [vcd_nsxt_security_group.demo.id]
    destination_ids      = [vcd_nsxt_ip_set.lab_dns.id]
    enabled              = true
    logging              = false
  }

  rule {
    name                 = "allow-demo-vms-to-lab-ntp"
    action               = "ALLOW"
    direction            = "OUT"
    ip_protocol          = "IPV4"
    app_port_profile_ids = [vcd_nsxt_app_port_profile.ntp.id]
    source_ids           = [vcd_nsxt_security_group.demo.id]
    destination_ids      = [vcd_nsxt_ip_set.lab_ntp.id]
    enabled              = true
    logging              = false
  }

  rule {
    name                 = "allow-demo-vms-https-out"
    action               = "ALLOW"
    direction            = "OUT"
    ip_protocol          = "IPV4"
    app_port_profile_ids = [vcd_nsxt_app_port_profile.https.id]
    source_ids           = [vcd_nsxt_security_group.demo.id]
    destination_ids      = []
    enabled              = true
    logging              = false
  }

  rule {
    name                 = "drop-other-inbound-to-demo-vms"
    action               = "DROP"
    direction            = "IN"
    ip_protocol          = "IPV4"
    app_port_profile_ids = []
    destination_ids      = [vcd_nsxt_security_group.demo.id]
    source_ids           = []
    enabled              = true
    logging              = false
  }

  depends_on = [
    vcd_nsxt_nat_rule.ssh_dnat,
    vcd_nsxt_nat_rule.outbound_snat
  ]
}
