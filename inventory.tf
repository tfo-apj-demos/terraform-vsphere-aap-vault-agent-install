# AAP inventory & host registration. Created before the VM module so the
# inventory is populated by the time the after_create jobs (lifecycle.tf)
# launch against it.

resource "aap_inventory" "vm_inventory" {
  name        = "${var.TFC_PROJECT_NAME} - ${var.TFC_WORKSPACE_NAME}"
  description = "Inventory for VMs built with HCP Terraform and managed by AAP"

  variables = jsonencode({
    os                 = values(var.vm_config)[0].os_type
    linux_distribution = values(var.vm_config)[0].linux_distribution
    tfc_workspace_url  = "https://app.terraform.io/app/tfo-apj-demos/workspaces/${var.TFC_WORKSPACE_NAME}"

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
    # Use the FQDN for SSH. Once the VM module runs, its DNS provider
    # (see provider.tf) registers the A record so SSH resolves to the
    # right IP for the after_create jobs.
    ansible_host = "${each.value.hostname}.${each.value.ad_domain}"
  })

  groups = [aap_group.vm_groups[each.value.security_profile].id]
}
