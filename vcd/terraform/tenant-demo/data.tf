data "vcd_provider_vdc" "provider" {
  name = var.provider_vdc_name
}

data "vcd_external_network_v2" "external" {
  name = var.provider_gateway_name
}

data "vcd_ip_space" "external" {
  name = var.ip_space_name
}

data "vcd_nsxt_edge_cluster" "edge_cluster" {
  name            = var.edge_cluster_name
  provider_vdc_id = data.vcd_provider_vdc.provider.id
}

data "vcd_vm_sizing_policy" "application" {
  name = var.vm_sizing_policy_name
}

data "vcd_storage_profile" "catalog" {
  org  = vcd_org_vdc.tenant.org
  vdc  = vcd_org_vdc.tenant.name
  name = one([for profile in var.storage_profiles : profile.name if profile.default])
}

data "vcd_nsxt_app_port_profile" "ssh" {
  name  = var.security.ssh_app_port_profile_name
  scope = "SYSTEM"
}
