output "vcfa_version" {
  value = data.vcfa_version.current.version
}

output "tenant_org" {
  value = vcfa_org.tenant.name
}

output "region" {
  value = data.vcfa_region.tenant.name
}

output "region_zone" {
  value = data.vcfa_region_zone.tenant.name
}

output "regional_networking" {
  value = vcfa_org_regional_networking.tenant.name
}

output "provider_gateway" {
  value = data.vcfa_provider_gateway.tenant.name
}

output "edge_cluster" {
  value = data.vcfa_edge_cluster.tenant.name
}

output "allowed_vm_classes" {
  value = sort(keys(data.vcfa_region_vm_class.tenant))
}

output "storage_policies" {
  value = sort(keys(data.vcfa_region_storage_policy.tenant))
}

output "content_library" {
  value = vcfa_content_library.application.name
}

output "tenant_admin_user" {
  value = vcfa_org_local_user.admin.username
}
