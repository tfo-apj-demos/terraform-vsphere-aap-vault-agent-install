# AAP inventory & host registration (created BEFORE the VM module so
# pre-VM action triggers run against a populated inventory).

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
    # Use the FQDN for SSH so pre-VM jobs see this host before the VM
    # exists. Once the VM module runs, its DNS provider (see provider.tf)
    # registers the A record and SSH resolves to the right IP.
    ansible_host = "${each.value.hostname}.${each.value.ad_domain}"
  })

  groups = [aap_group.vm_groups[each.value.security_profile].id]

  # Pre-VM lifecycle hooks — fire per host before the VM module mutates
  # the underlying VM. wait_for_completion on each action serialises the
  # snapshot + LB-drain work against this host.
  # lifecycle {
  #   action_trigger {
  #     events = [before_update]
  #     actions = [
  #       action.aap_job_launch.vsphere_snapshot,
  #       action.aap_job_launch.lb_pool_drain,
  #     ]
  #   }
  # }
}
