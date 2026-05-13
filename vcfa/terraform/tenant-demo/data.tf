data "vcfa_region" "tenant" {
  name = var.provider_infrastructure.region_name
}

data "vcfa_vcenter" "tenant" {
  name = var.provider_infrastructure.vcenter_name
}

data "vcfa_supervisor" "tenant" {
  name       = var.provider_infrastructure.supervisor_name
  vcenter_id = data.vcfa_vcenter.tenant.id
}

data "vcfa_region_zone" "tenant" {
  name      = var.provider_infrastructure.region_zone_name
  region_id = data.vcfa_region.tenant.id
}

data "vcfa_provider_gateway" "tenant" {
  name      = var.provider_infrastructure.provider_gateway_name
  region_id = data.vcfa_region.tenant.id
}

data "vcfa_edge_cluster" "tenant" {
  name             = var.provider_infrastructure.edge_cluster_name
  region_id        = data.vcfa_region.tenant.id
  sync_before_read = true
}

data "vcfa_region_vm_class" "tenant" {
  for_each  = var.region_quota.vm_class_names
  name      = each.value
  region_id = data.vcfa_region.tenant.id
}

data "vcfa_region_storage_policy" "tenant" {
  for_each  = var.region_quota.storage_policies
  name      = each.key
  region_id = data.vcfa_region.tenant.id
}

data "vcfa_storage_class" "library" {
  for_each  = var.application.content_library_storage_classes
  name      = each.value
  region_id = data.vcfa_region.tenant.id
}

data "vcfa_role" "org_admin" {
  org_id = vcfa_org.tenant.id
  name   = "Organization Administrator"
}
