terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2"
    }
    # Ansible Autoimation Platform Provider
    aap = {
      source  = "ansible/aap"
      version = "~> 1"
    }
  }
}