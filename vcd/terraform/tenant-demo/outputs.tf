output "tenant_org" {
  value = vcd_org.tenant.name
}

output "tenant_vdc" {
  value = vcd_org_vdc.tenant.name
}

output "edge_gateway" {
  value = vcd_nsxt_edgegateway.tenant.name
}

output "routed_network" {
  value = vcd_network_routed_v2.tenant.name
}

output "catalog" {
  value = vcd_catalog.application.name
}

# OVA/template upload is disabled in this advanced dummy-VM variant.
# output "demo_template" {
#   value = vcd_catalog_vapp_template.demo.name
# }

output "named_disk" {
  value = vcd_independent_disk.shared.name
}

output "application_vms" {
  value = sort(keys(local.demo_vms))
}

output "demo_security_group" {
  value = vcd_nsxt_security_group.demo.name
}

output "ssh_dnat_ips" {
  value = {
    for vm_name, allocation in vcd_ip_space_ip_allocation.ssh_dnat : vm_name => allocation.ip
  }
}

output "tenant_ldap_users" {
  value = sort(keys(vcd_org_user.ldap))
}

output "tenant_ip_sets" {
  value = {
    trusted_admin_sources = vcd_nsxt_ip_set.trusted_admin_sources.name
    lab_dns               = vcd_nsxt_ip_set.lab_dns.name
    lab_ntp               = vcd_nsxt_ip_set.lab_ntp.name
  }
}

output "tenant_app_port_profiles" {
  value = {
    dns   = vcd_nsxt_app_port_profile.dns.name
    ntp   = vcd_nsxt_app_port_profile.ntp.name
    https = vcd_nsxt_app_port_profile.https.name
  }
}

output "outbound_snat" {
  value = vcd_nsxt_nat_rule.outbound_snat.name
}
