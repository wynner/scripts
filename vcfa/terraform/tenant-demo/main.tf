terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vcfa = {
      source  = "vmware/vcfa"
      version = "~> 1.0"
    }
  }
}

provider "vcfa" {
  user                 = var.vcfa_user
  password             = var.vcfa_password
  auth_type            = "integrated"
  org                  = var.vcfa_org
  url                  = var.vcfa_url
  allow_unverified_ssl = var.vcfa_allow_unverified_ssl
}

data "vcfa_version" "current" {
  condition         = ">= 9.0.0"
  fail_if_not_match = true
}
