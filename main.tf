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
  for_each               = var.vm_config
  source                 = "git::https://github.com/tfo-apj-demos/terraform-vsphere-single-virtual-machine-prevent-destroy.git?ref=v1.0.0"
  fallback_template_name = "base-rhel-9-20250501083042_vtpm" # Manual override

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
  name        = "Better Together Demo - ${var.TFC_PROJECT_NAME} - ${var.TFC_WORKSPACE_NAME}"
  description = "Inventory for VMs built with HCP Terraform and managed by AAP"

  variables = jsonencode({
    os                 = values(var.vm_config)[0].os_type
    linux_distribution = values(var.vm_config)[0].linux_distribution
  })
}

# Create AAP groups per security profile
resource "aap_group" "vm_groups" {
  for_each = toset([
    for vm in var.vm_config : vm.security_profile
    if length(vm.security_profile) > 0
  ])

  inventory_id = aap_inventory.vm_inventory.id
  name         = replace(each.value, "-", "_")

  variables = jsonencode({
    # Get the first VM with this security profile for site/env values
    site = [for vm in var.vm_config : vm.site if vm.security_profile == each.value][0]
    env  = [for vm in var.vm_config : vm.environment if vm.security_profile == each.value][0]
  })
}

# Create AAP hosts from the VM config
resource "aap_host" "vm_hosts" {
  for_each = var.vm_config

  inventory_id = aap_inventory.vm_inventory.id
  name         = each.value.hostname

  variables = jsonencode({
    os_type           = each.value.os_type
    backup_policy     = each.value.backup_policy
    storage_profile   = each.value.storage_profile
    tier              = each.value.tier
    cert_service_type = each.value.cert_service_type
    ansible_host      = module.single_virtual_machine[each.key].ip_address
  })

  groups = [aap_group.vm_groups[each.value.security_profile].id]
}


# Look up the AAP job template for RHEL registration
data "aap_job_template" "rhel_register" {
  name              = "rhel-register"
  organization_name = "Default"
}

# Look up the AAP job template by name to avoid hardcoding IDs
data "aap_job_template" "vault_agent" {
  name              = "rhel-install-vault-agent"
  organization_name = "Default"
}

# Launch the RHEL registration job as an action
action "aap_job_launch" "rhel_register" {
  config {
    job_template_id                     = data.aap_job_template.rhel_register.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1000
  }
}

# Launch the AAP job as an action (fire-and-forget, not tracked in state)
action "aap_job_launch" "vault_agent" {
  config {
    job_template_id                     = data.aap_job_template.vault_agent.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1000
  }
}

# Look up the AAP job template for nginx installation
data "aap_job_template" "install_nginx" {
  name              = "rhel-install-nginx"
  organization_name = "Default"
}

# Launch the nginx install job as an action
action "aap_job_launch" "install_nginx" {
  config {
    job_template_id                     = data.aap_job_template.install_nginx.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1000
  }
}

# Trigger the AAP job after VMs are created or updated
resource "terraform_data" "vm_provisioned" {

  input = local.vm_names

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.rhel_register, action.aap_job_launch.vault_agent, action.aap_job_launch.install_nginx]
    }
  }
}