# Terraform vSphere VM Build with AAP and Vault Agent

# Define local VM names as a map to be used in the AAP job triggers
locals {
  vm_names = { for vm_key, vm_value in module.single_virtual_machine : vm_key => vm_value.virtual_machine_name }
}

# Iterate over each VM config to create instances of the module
module "single_virtual_machine" {
  for_each = var.vm_config

  source  = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version = "~> 1.2"

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

# Create AAP inventory for VMs
resource "aap_inventory" "vm_inventory" {
  name        = "GCVE VM Inventory - ${var.TFC_WORKSPACE_ID}"
  description = "Inventory for deployed virtual machines in GCVE"

  # Add any relevant inventory-wide variables here
  variables = jsonencode({ "os" : "Linux", "automation" : "ansible" })
}

# Create AAP groups based on security profile
resource "aap_group" "vm_groups" {
  for_each = { for key, vm in var.vm_config : vm.security_profile => vm if length(vm.security_profile) > 0 }

  inventory_id = aap_inventory.vm_inventory.id
  name         = replace(each.key, "-", "_") # Replace hyphen with underscore for group name

  # Define group-specific variables
  variables = jsonencode({
    "environment" : each.value.environment,
    "site" : each.value.site
  })
}

# Create AAP hosts for each VM with specific variables
resource "aap_host" "vm_hosts" {
  for_each = var.vm_config

  inventory_id = aap_inventory.vm_inventory.id
  name         = each.value.hostname # Use the hostname for each VM
  variables = jsonencode({
    "backup_policy" : each.value.backup_policy,
    "os_type" : each.value.os_type,
    "storage_profile" : each.value.storage_profile,
    "tier" : each.value.tier,
    "ansible_host" : module.single_virtual_machine[each.key].ip_address # Reference the IP address from the module
  })

  # Associate each host with its respective group based on security profile
  groups = [aap_group.vm_groups[each.value.security_profile].id]
}

# Create an AAP job that will run against the VM inventory
resource "aap_job" "vm_demo_job" {
  job_template_id = var.job_template_id
  inventory_id    = aap_inventory.vm_inventory.id
  extra_vars      = jsonencode({})

  triggers = local.vm_names
}