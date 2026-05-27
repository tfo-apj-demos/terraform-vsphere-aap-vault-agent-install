module "single_virtual_machine" {
  for_each               = var.vm_config
  source                 = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version                = "~> 2.1"
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
