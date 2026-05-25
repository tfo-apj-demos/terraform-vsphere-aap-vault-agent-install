# Job template data sources — looked up by name from AAP. Used by the
# action blocks in actions.tf.

# Provisioning stack:
data "aap_job_template" "rhel_register" {
  name              = "rhel-register"
  organization_name = "Default"
}

data "aap_job_template" "install_nginx" {
  name              = "rhel-install-nginx"
  organization_name = "Default"
}

data "aap_job_template" "chrony_timesync" {
  name              = "rhel-chrony-timesync"
  organization_name = "Default"
}

# Workflow job template (multi-step) — needs the workflow-specific data
# source; launched via aap_workflow_job_launch.
data "aap_workflow_job_template" "clm_issue_deploy_verify" {
  name              = "CLM - Issue, Deploy & Verify"
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
