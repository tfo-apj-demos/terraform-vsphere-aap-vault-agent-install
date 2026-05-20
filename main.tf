# HCP Terraform: vSphere VM Build with Ansible Automation Platform and HashiCorp Vault Agent
#
# Lifecycle wiring:
#   aap_host.vm_hosts            → before_create / before_update (per-VM)
#   terraform_data.vm_provisioned → after_create  / after_update
#
# aap_host is independent of the VM module (uses FQDN for ansible_host).
# Putting before_* on aap_host means the action triggers don't need a
# depends_on link into the VM module — which is important because that
# explicit dep forces the upstream tags-submodule data sources to defer to
# apply time, and the comprehension `[for tag in module.tags : tag.tag_id]`
# in app.terraform.io/tfo-apj-demos/virtual-machine/vsphere v2.0.2 then
# fails plan-time schema validation with "Null value found in list".

locals {
  vm_names = {
    for vm_key, vm_value in module.single_virtual_machine :
    vm_key => vm_value.virtual_machine_name
  }
  vm_ips = {
    for vm_key, vm_value in module.single_virtual_machine :
    vm_key => vm_value.ip_address
  }
}

# ─────────────────────────────────────────────────────────────────────────
# AAP inventory & host registration (created BEFORE the VM module so
# pre-VM action triggers run against a populated inventory).
# ─────────────────────────────────────────────────────────────────────────

resource "aap_inventory" "vm_inventory" {
  name        = "Better Together Demo - ${var.TFC_PROJECT_NAME} - ${var.TFC_WORKSPACE_NAME}"
  description = "Inventory for VMs built with HCP Terraform and managed by AAP"

  variables = jsonencode({
    os                 = values(var.vm_config)[0].os_type
    linux_distribution = values(var.vm_config)[0].linux_distribution
  })
}

resource "aap_group" "vm_groups" {
  for_each = toset([
    for vm in var.vm_config : vm.security_profile
    if length(vm.security_profile) > 0
  ])

  inventory_id = aap_inventory.vm_inventory.id
  name         = replace(each.value, "-", "_")

  variables = jsonencode({
    site = [for vm in var.vm_config : vm.site if vm.security_profile == each.value][0]
    env  = [for vm in var.vm_config : vm.environment if vm.security_profile == each.value][0]
  })
}

resource "aap_host" "vm_hosts" {
  for_each = var.vm_config

  inventory_id = aap_inventory.vm_inventory.id
  name         = each.value.hostname

  variables = jsonencode({
    os_type            = each.value.os_type
    backup_policy      = each.value.backup_policy
    storage_profile    = each.value.storage_profile
    tier               = each.value.tier
    cert_service_type  = each.value.cert_service_type
    site               = each.value.site
    env                = each.value.environment
    security_profile   = each.value.security_profile
    ad_domain          = each.value.ad_domain
    tfc_workspace_name = var.TFC_WORKSPACE_NAME
    tfc_run_id         = var.TFC_RUN_ID
    # Use the FQDN for SSH so pre-VM jobs see this host before the VM
    # exists. Once the VM module runs, its DNS provider (see provider.tf)
    # registers the A record and SSH resolves to the right IP.
    ansible_host = "${each.value.hostname}.${each.value.ad_domain}"
  })

  groups = [aap_group.vm_groups[each.value.security_profile].id]

  # Pre-VM lifecycle hooks — fire per host before the VM module mutates
  # the underlying VM. wait_for_completion on each action serialises the
  # CMDB / IPAM / snapshot / LB-drain work against this host.
  lifecycle {
    action_trigger {
      events = [before_create]
      actions = [
        action.aap_job_launch.cmdb_change_open,
        action.aap_job_launch.ipam_reserve,
      ]
    }
    action_trigger {
      events = [before_update]
      actions = [
        action.aap_job_launch.cmdb_change_open,
        action.aap_job_launch.vsphere_snapshot,
        action.aap_job_launch.lb_pool_drain,
      ]
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────
# VM build (private module from PMR)
# ─────────────────────────────────────────────────────────────────────────
#
# No explicit depends_on into aap_host here — depends_on at the module
# scope forces all the module's data sources (vsphere_tag, vsphere_tag_category
# x6, vsphere_datastore, vsphere_network, …) to defer to apply time, which
# in turn makes the module's `tags = [for t in module.tags : t.tag_id]`
# resolve to a null-bearing list at plan time and fail schema validation.
# aap_host has no data dependency on the module, so Terraform's graph
# walker schedules its creation first in practice — the pre-VM actions
# run in the same scheduling layer as the VM build, and wait_for_completion
# on the actions serialises within the host.

module "single_virtual_machine" {
  for_each               = var.vm_config
  source                 = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version                = "~> 2.0"
  fallback_template_name = "base-rhel-9-20250501083042_vtpm"

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

# ─────────────────────────────────────────────────────────────────────────
# Job template data sources
# ─────────────────────────────────────────────────────────────────────────

# Existing (kept):
data "aap_job_template" "rhel_register" {
  name              = "rhel-register"
  organization_name = "Default"
}

data "aap_job_template" "vault_agent" {
  name              = "rhel-install-vault-agent"
  organization_name = "Default"
}

data "aap_job_template" "install_nginx" {
  name              = "rhel-install-nginx"
  organization_name = "Default"
}

# Pre-VM (before_create / before_update):
data "aap_job_template" "cmdb_change_open" {
  name              = "pre-cmdb-change-open"
  organization_name = "Default"
}

data "aap_job_template" "ipam_reserve" {
  name              = "pre-ipam-reserve"
  organization_name = "Default"
}

data "aap_job_template" "vsphere_snapshot" {
  name              = "pre-vsphere-snapshot"
  organization_name = "Default"
}

data "aap_job_template" "lb_pool_drain" {
  name              = "pre-lb-pool-drain"
  organization_name = "Default"
}

# Post-VM (after_create / after_update):
data "aap_job_template" "cis_hardening" {
  name              = "rhel-cis-hardening"
  organization_name = "Default"
}

data "aap_job_template" "chrony_timesync" {
  name              = "rhel-chrony-timesync"
  organization_name = "Default"
}

data "aap_job_template" "ad_domain_join" {
  name              = "rhel-ad-domain-join"
  organization_name = "Default"
}

data "aap_job_template" "splunk_uf_install" {
  name              = "rhel-splunk-uf-install"
  organization_name = "Default"
}

data "aap_job_template" "crowdstrike_install" {
  name              = "rhel-crowdstrike-install"
  organization_name = "Default"
}

data "aap_job_template" "qualys_install" {
  name              = "rhel-qualys-install"
  organization_name = "Default"
}

# Post-update validation & re-enable:
data "aap_job_template" "post_change_validate" {
  name              = "rhel-post-change-validate"
  organization_name = "Default"
}

data "aap_job_template" "lb_pool_reenable" {
  name              = "post-lb-pool-reenable"
  organization_name = "Default"
}

# ─────────────────────────────────────────────────────────────────────────
# Action blocks
#
# Each action.aap_job_launch wraps one AAP job template. wait_for_completion
# is true so any failure propagates up and fails the Terraform apply — which
# is what a bank change-control workflow expects.
# ─────────────────────────────────────────────────────────────────────────

# Existing:
action "aap_job_launch" "rhel_register" {
  config {
    job_template_id                     = data.aap_job_template.rhel_register.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1000
  }
}

action "aap_job_launch" "vault_agent" {
  config {
    job_template_id                     = data.aap_job_template.vault_agent.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1000
  }
}

action "aap_job_launch" "install_nginx" {
  config {
    job_template_id                     = data.aap_job_template.install_nginx.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1000
  }
}

# Pre-VM:
action "aap_job_launch" "cmdb_change_open" {
  config {
    job_template_id                     = data.aap_job_template.cmdb_change_open.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
  }
}

action "aap_job_launch" "ipam_reserve" {
  config {
    job_template_id                     = data.aap_job_template.ipam_reserve.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
  }
}

action "aap_job_launch" "vsphere_snapshot" {
  config {
    job_template_id                     = data.aap_job_template.vsphere_snapshot.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1200
  }
}

action "aap_job_launch" "lb_pool_drain" {
  config {
    job_template_id                     = data.aap_job_template.lb_pool_drain.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
  }
}

# Post-VM (after_create / after_update):
action "aap_job_launch" "cis_hardening" {
  config {
    job_template_id                     = data.aap_job_template.cis_hardening.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1200
  }
}

action "aap_job_launch" "chrony_timesync" {
  config {
    job_template_id                     = data.aap_job_template.chrony_timesync.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
  }
}

action "aap_job_launch" "ad_domain_join" {
  config {
    job_template_id                     = data.aap_job_template.ad_domain_join.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 900
  }
}

action "aap_job_launch" "splunk_uf_install" {
  config {
    job_template_id                     = data.aap_job_template.splunk_uf_install.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1200
  }
}

action "aap_job_launch" "crowdstrike_install" {
  config {
    job_template_id                     = data.aap_job_template.crowdstrike_install.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1200
  }
}

action "aap_job_launch" "qualys_install" {
  config {
    job_template_id                     = data.aap_job_template.qualys_install.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 900
  }
}

# Post-update only:
action "aap_job_launch" "post_change_validate" {
  config {
    job_template_id                     = data.aap_job_template.post_change_validate.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
  }
}

action "aap_job_launch" "lb_pool_reenable" {
  config {
    job_template_id                     = data.aap_job_template.lb_pool_reenable.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 900
  }
}

# ─────────────────────────────────────────────────────────────────────────
# Post-VM lifecycle hook
# ─────────────────────────────────────────────────────────────────────────

resource "terraform_data" "vm_provisioned" {
  input = local.vm_names

  lifecycle {
    # Idempotent configuration applied on both create and update.
    action_trigger {
      events = [after_create, after_update]
      actions = [
        action.aap_job_launch.rhel_register,
        action.aap_job_launch.cis_hardening,
        action.aap_job_launch.chrony_timesync,
        action.aap_job_launch.ad_domain_join,
        action.aap_job_launch.vault_agent,
        action.aap_job_launch.splunk_uf_install,
        action.aap_job_launch.crowdstrike_install,
        action.aap_job_launch.qualys_install,
        action.aap_job_launch.install_nginx,
      ]
    }

    # Update-only — these only make sense after the VM was already in service.
    action_trigger {
      events = [after_update]
      actions = [
        action.aap_job_launch.post_change_validate,
        action.aap_job_launch.lb_pool_reenable,
      ]
    }
  }
}
