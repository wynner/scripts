variable "vcd_url" {
  description = "VMware Cloud Director API URL, for example https://vcd.domain.com/api."
  type        = string
}

variable "vcd_user" {
  description = "System administrator username."
  type        = string
}

variable "vcd_password" {
  description = "System administrator password."
  type        = string
  sensitive   = true
}

variable "vcd_allow_unverified_ssl" {
  description = "Allow self-signed or private CA certificates."
  type        = bool
  default     = true
}

variable "vcd_max_retry_timeout" {
  description = "Provider retry timeout in seconds."
  type        = number
  default     = 120
}

variable "tenant" {
  description = "Tenant identity and VDC naming."
  type = object({
    org_name      = string
    org_full_name = string
    org_vdc_name  = string
    edge_name     = string
    network_name  = string
    admin_user    = string
    admin_email   = optional(string)
  })
}

variable "tenant_admin_password" {
  description = "Initial password for the tenant organization administrator."
  type        = string
  sensitive   = true
}

variable "tenant_vdc_enabled" {
  description = "Whether the tenant VDC is enabled. Set false before destroy when VCD requires disabled VDC deletion."
  type        = bool
  default     = true
}

variable "provider_vdc_name" {
  description = "Existing Provider VDC backing the tenant VDC."
  type        = string

  validation {
    condition     = !startswith(lower(var.provider_vdc_name), "urn:") && !can(regex("^[0-9a-fA-F-]{36}$", var.provider_vdc_name))
    error_message = "Use the Provider VDC display name, not a UUID or URN."
  }
}

variable "network_pool_name" {
  description = "Existing VCD network pool assigned to the tenant VDC."
  type        = string

  validation {
    condition     = !startswith(lower(var.network_pool_name), "urn:") && !can(regex("^[0-9a-fA-F-]{36}$", var.network_pool_name))
    error_message = "Use the network pool display name, not a UUID or URN."
  }
}

variable "provider_gateway_name" {
  description = "Existing NSX-T Provider Gateway or external network display name exposed in VCD."
  type        = string

  validation {
    condition     = !startswith(lower(var.provider_gateway_name), "urn:") && !can(regex("^[0-9a-fA-F-]{36}$", var.provider_gateway_name))
    error_message = "Use the Provider Gateway or external network display name, not a UUID or URN."
  }
}

variable "ip_space_name" {
  description = "Existing IP Space used to allocate DNAT floating IPs."
  type        = string

  validation {
    condition     = !startswith(lower(var.ip_space_name), "urn:") && !can(regex("^[0-9a-fA-F-]{36}$", var.ip_space_name))
    error_message = "Use the IP Space display name, not a UUID or URN."
  }
}

variable "edge_cluster_name" {
  description = "Existing NSX-T Edge Cluster name as shown in VCD."
  type        = string

  validation {
    condition     = !startswith(lower(var.edge_cluster_name), "urn:") && !can(regex("^[0-9a-fA-F-]{36}$", var.edge_cluster_name))
    error_message = "Use the Edge Cluster display name, not a UUID or URN."
  }
}

variable "vm_sizing_policy_name" {
  description = "VM sizing policy used for the application VMs and as the VDC default."
  type        = string
  default     = "Medium"

  validation {
    condition     = !startswith(lower(var.vm_sizing_policy_name), "urn:") && !can(regex("^[0-9a-fA-F-]{36}$", var.vm_sizing_policy_name))
    error_message = "Use the VM sizing policy display name, not a UUID or URN."
  }
}

variable "storage_profiles" {
  description = "Storage profiles to expose to the tenant VDC."
  type = list(object({
    name    = string
    limit   = number
    default = bool
  }))
}

variable "vdc_compute" {
  description = "Flex allocation limits for the tenant VDC."
  type = object({
    cpu_allocated_mhz = number
    cpu_limit_mhz     = number
    cpu_speed_mhz     = number
    memory_allocated  = number
    memory_limit      = number
  })
}

variable "routed_network" {
  description = "Internal routed network created behind the tenant edge."
  type = object({
    gateway       = string
    prefix_length = number
    cidr          = optional(string)
    pool_start    = string
    pool_end      = string
    dns1          = string
    dns2          = string
    dns_suffix    = string
  })
}

variable "application" {
  description = "Catalog, Named Disk, and VM settings for the demo application."
  type = object({
    catalog_name               = string
    catalog_description        = optional(string)
    demo_template_name         = optional(string)
    demo_template_desc         = optional(string)
    demo_ova_path              = optional(string)
    upload_piece_size_mb       = optional(number, 10)
    named_disk_name            = string
    named_disk_size_mb         = number
    named_disk_bus_type        = optional(string, "SCSI")
    named_disk_bus_sub_type    = optional(string, "lsilogicsas")
    named_disk_sharing_type    = optional(string, "ControllerSharing")
    named_disk_storage_profile = string
    vm_storage_profile         = string
    vm_names                   = list(string)
    vm_os_type                 = optional(string, "otherGuest64")
    vm_hardware_version        = optional(string, "vmx-19")
    vm_cpus                    = optional(number, 1)
    vm_cpu_cores               = optional(number, 1)
    vm_memory_mb               = optional(number, 1024)
    vm_internal_disk_size_mb   = optional(number, 10240)
    vm_internal_disk_bus_type  = optional(string, "nvme")
    vm_internal_disk_bus       = optional(number, 0)
    vm_internal_disk_unit      = optional(number, 0)
    power_on                   = optional(bool, true)
  })

  validation {
    condition     = length(var.application.vm_names) == 2
    error_message = "This demo expects exactly two VM names."
  }
}

variable "security" {
  description = "Security group, SSH DNAT, and firewall settings for the demo application."
  type = object({
    demo_security_group_name  = optional(string, "Demo VM Group")
    ssh_app_port_profile_name = optional(string, "SSH")
    ssh_dnat_external_ips     = optional(map(string), {})
    trusted_admin_sources     = optional(list(string), ["0.0.0.0/0"])
    lab_dns_servers           = list(string)
    lab_ntp_servers           = list(string)
  })
}

variable "tenant_ldap_users" {
  description = "LDAP-backed users to import into the tenant organization. Leave empty if the target org LDAP provider is not ready."
  type = map(object({
    role              = string
    full_name         = optional(string)
    email_address     = optional(string)
    deployed_vm_quota = optional(number, 0)
    stored_vm_quota   = optional(number, 0)
    enabled           = optional(bool, true)
  }))
  default = {}
}

variable "common_metadata" {
  description = "Metadata applied to major tenant demo resources."
  type        = map(string)
  default = {
    managed-by = "terraform"
    purpose    = "vcd-tenant-demo"
  }
}
