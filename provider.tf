terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2"
    }
    aap = {
      source  = "ansible/aap"
      version = "~> 1"
    }
  }
}