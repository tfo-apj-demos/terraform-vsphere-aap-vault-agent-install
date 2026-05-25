terraform {
  required_version = ">= 1.14"

  cloud {
    organization = "tfo-apj-demos"
    workspaces {
      name = "better-together-vm-lifecycle-dev"
    }
  }

  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.15"
    }
    # 1.5.0+ required for the aap_workflow_job_launch action (CLM cert
    # workflow in actions.tf); 1.4.0 only had aap_job_launch.
    aap = {
      source  = "ansible/aap"
      version = "~> 1.5.0"
    }
    # Required by single-virtual-machine module
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.111"
    }
    ad = {
      source  = "hashicorp/ad"
      version = "~> 0.5"
    }
    dns = {
      source = "hashicorp/dns"
      # Pinned below 3.6.0 — 3.6.0 broke GSS-TSIG against Windows AD DNS via
      # the bodgit/tsig 1.3.0 dep bump. See docs/DNS-GSS-TSIG-INVESTIGATION.md
      # and hashicorp/terraform-provider-dns#642.
      version = ">= 3.4.3, < 3.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Credentials via env vars: VSPHERE_USER, VSPHERE_PASSWORD, VSPHERE_SERVER.
provider "vsphere" {
  allow_unverified_ssl = true
}

provider "hcp" {
  project_id = "11eb56d6-0f95-3a99-a33c-0242ac110007"
}

provider "aap" {
  timeout = 30
}