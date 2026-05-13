variable "vcfa_url" {
  description = "VCFA endpoint URL, for example https://vcfa.domain.com."
  type        = string
}

variable "vcfa_user" {
  description = "Provider-local or integrated user for VCFA API operations."
  type        = string
  sensitive   = true
}

variable "vcfa_password" {
  description = "Password for VCFA API operations."
  type        = string
  sensitive   = true
}

variable "vcfa_org" {
  description = "VCFA organization used for provider operations. Use System for provider-layer tenant setup."
  type        = string
  default     = "System"
}

variable "vcfa_allow_unverified_ssl" {
  description = "Allow self-signed or private CA certificates."
  type        = bool
  default     = true
}

variable "tenant" {
  description = "Tenant identity, local admin, and regional networking names."
  type = object({
    name                  = string
    display_name          = string
    description           = optional(string)
    networking_log_name   = string
    regional_network_name = string
    admin_username        = string
  })

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.tenant.name))
    error_message = "Use a lowercase ASCII tenant name with hyphens, for example demo-tf."
  }

  validation {
    condition     = length(var.tenant.networking_log_name) >= 1 && length(var.tenant.networking_log_name) <= 8 && can(regex("^[a-z0-9]+$", var.tenant.networking_log_name))
    error_message = "The VCFA networking log name must be 1-8 lowercase alphanumeric characters."
  }
}

variable "tenant_admin_password" {
  description = "Initial password for the Terraform-created local tenant administrator."
  type        = string
  sensitive   = true
}

variable "provider_infrastructure" {
  description = "Existing VCFA provider-side objects used to back the tenant."
  type = object({
    region_name           = string
    region_zone_name      = string
    vcenter_name          = string
    supervisor_name       = string
    provider_gateway_name = string
    edge_cluster_name     = string
  })

  validation {
    condition = alltrue([
      for value in values(var.provider_infrastructure) :
      !startswith(lower(value), "urn:") && !can(regex("^[0-9a-fA-F-]{36}$", value))
    ])
    error_message = "Use provider-side display names, not UUIDs or URNs."
  }
}

variable "region_quota" {
  description = "Region quota, storage policies, and VM classes exposed to the tenant."
  type = object({
    cpu_limit_mhz          = number
    cpu_reservation_mhz    = optional(number, 0)
    memory_limit_mib       = number
    memory_reservation_mib = optional(number, 0)
    vm_class_names         = set(string)
    storage_policies = map(object({
      limit_mib = number
    }))
  })

  validation {
    condition     = length(var.region_quota.vm_class_names) > 0
    error_message = "Expose at least one VM class to the tenant."
  }

  validation {
    condition     = length(var.region_quota.storage_policies) > 0
    error_message = "Expose at least one storage policy to the tenant."
  }
}

variable "application" {
  description = "Application-facing objects that the VCFA provider can model."
  type = object({
    content_library_name        = string
    content_library_description = optional(string)
    content_library_storage_classes = optional(set(string), [
      "Standard"
    ])
  })

  validation {
    condition     = length(var.application.content_library_storage_classes) > 0
    error_message = "Use at least one storage class for the tenant content library."
  }
}
