terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2"
    }
    # Ansible Automation Platform Provider
    aap = {
      source  = "ansible/aap"
      version = "~> 1.2"
    }
  }
}

provider "aap" {
}