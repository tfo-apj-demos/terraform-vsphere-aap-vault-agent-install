terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2"
    }
    # Ansible Automation Platform Provider
    aap = {
      source  = "ansible/aap"
      version = "~> 1.2"
    }
    # Required by single-virtual-machine module
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.104"
    }
    ad = {
      source  = "hashicorp/ad"
      version = "~> 0.5"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# vSphere provider configuration
# Uses environment variables: VSPHERE_USER, VSPHERE_PASSWORD, VSPHERE_SERVER
provider "vsphere" {
  allow_unverified_ssl = true
}

# HCP provider configuration
provider "hcp" {
  project_id = "11eb56d6-0f95-3a99-a33c-0242ac110007"
}

# Ansible Automation Platform provider
provider "aap" {
}