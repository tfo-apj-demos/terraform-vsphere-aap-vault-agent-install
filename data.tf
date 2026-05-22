# Job template data sources — looked up by name from AAP. Used by the
# action blocks in actions.tf.

# Core after_create stack:
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

data "aap_job_template" "cis_hardening" {
  name              = "rhel-cis-hardening"
  organization_name = "Default"
}

data "aap_job_template" "chrony_timesync" {
  name              = "rhel-chrony-timesync"
  organization_name = "Default"
}

# Pre-VM (before_update — both currently commented out on aap_host):
data "aap_job_template" "vsphere_snapshot" {
  name              = "pre-vsphere-snapshot"
  organization_name = "Default"
}

data "aap_job_template" "lb_pool_drain" {
  name              = "pre-lb-pool-drain"
  organization_name = "Default"
}

# Ad-hoc vSphere ops (no lifecycle trigger — surfaced in the TFC UI for
# the workspace developer to invoke on demand).
data "aap_job_template" "vsphere_power_off" {
  name              = "vsphere-power-off"
  organization_name = "Default"
}

data "aap_job_template" "vsphere_power_on" {
  name              = "vsphere-power-on"
  organization_name = "Default"
}

data "aap_job_template" "vsphere_guest_reboot" {
  name              = "vsphere-guest-reboot"
  organization_name = "Default"
}

data "aap_job_template" "vsphere_revert_snapshot" {
  name              = "vsphere-revert-snapshot"
  organization_name = "Default"
}

data "aap_job_template" "vsphere_remove_all_snapshots" {
  name              = "vsphere-remove-all-snapshots"
  organization_name = "Default"
}
