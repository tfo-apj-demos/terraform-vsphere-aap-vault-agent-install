# HCP Terraform: vSphere VM Build with Ansible Automation Platform and HashiCorp Vault Agent

# Extract VM names for use in AAP job triggers
locals {
  vm_names = {
    for vm_key, vm_value in module.single_virtual_machine :
    vm_key => vm_value.virtual_machine_name
  }
}

# Build VMs using a private module from the Private Module Registry
module "single_virtual_machine" {
  for_each = var.vm_config
  source   = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version  = "~> 1.3"

  hostname           = each.value.hostname
  ad_domain          = each.value.ad_domain
  backup_policy      = each.value.backup_policy
  environment        = each.value.environment
  os_type            = each.value.os_type
  linux_distribution = each.value.linux_distribution
  security_profile   = each.value.security_profile
  site               = each.value.site
  size               = each.value.size
  storage_profile    = each.value.storage_profile
  tier               = each.value.tier
}

# Create an AAP inventory for this workspace
resource "aap_inventory" "vm_inventory" {
  name        = "Better Together Demo - ${var.TFC_WORKSPACE_ID}"
  description = "Inventory for VMs built with HCP Terraform and managed by AAP"

  variables = jsonencode({
    os                 = one(values(var.vm_config)).os_type
    linux_distribution = one(values(var.vm_config)).linux_distribution
    security_profile   = one(values(var.vm_config)).security_profile
  })
}

# Create AAP groups per security profile
resource "aap_group" "vm_groups" {
  for_each = {
    for key, vm in var.vm_config : vm.security_profile => vm
    if length(vm.security_profile) > 0
  }

  inventory_id = aap_inventory.vm_inventory.id
  name         = replace(each.key, "-", "_")

  variables = jsonencode({
    site = each.value.site
    env  = each.value.environment
  })
}

# Create AAP hosts from the VM config
resource "aap_host" "vm_hosts" {
  for_each = var.vm_config

  inventory_id = aap_inventory.vm_inventory.id
  name         = each.value.hostname

  variables = jsonencode({
    os_type         = each.value.os_type
    backup_policy   = each.value.backup_policy
    storage_profile = each.value.storage_profile
    tier            = each.value.tier
    ansible_host    = module.single_virtual_machine[each.key].ip_address
  })

  groups = [aap_group.vm_groups[each.value.security_profile].id]
}


# rhel-install-vault-agent
data "aap_job_template" "vault_agent" {
  name = "rhel-install-vault-agent"
  organization_name = "Default"
}

# Run AAP job on deployed VMs
resource "aap_job" "vm_demo_job" {
  job_template_id = data.aap_job_template.vault_agent.id
  inventory_id    = aap_inventory.vm_inventory.id
  extra_vars      = jsonencode({})

  triggers = local.vm_names
}