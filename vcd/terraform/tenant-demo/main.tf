terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "~> 3.14"
    }
  }
}

provider "vcd" {
  user                 = var.vcd_user
  password             = var.vcd_password
  org                  = "System"
  url                  = var.vcd_url
  allow_unverified_ssl = var.vcd_allow_unverified_ssl
  max_retry_timeout    = var.vcd_max_retry_timeout
}
