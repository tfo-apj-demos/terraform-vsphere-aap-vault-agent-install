# VM build (private module from PMR)
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
