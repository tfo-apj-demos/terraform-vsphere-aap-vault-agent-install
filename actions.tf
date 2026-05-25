# Action blocks
#
# Each action.aap_job_launch wraps one AAP job template (looked up in
# data.tf). wait_for_completion is true so any failure propagates up and
# fails the Terraform apply — which is what a bank change-control
# workflow expects.

# Provisioning stack — wired into lifecycle.tf via
# terraform_data.vm_provisioned:
#   after_create: rhel_register, install_nginx, clm_issue_deploy_verify
#   after_update: chrony_timesync
action "aap_job_launch" "rhel_register" {
  config {
    job_template_id                     = data.aap_job_template.rhel_register.id
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

action "aap_job_launch" "chrony_timesync" {
  config {
    job_template_id                     = data.aap_job_template.chrony_timesync.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
  }
}

# Certificate lifecycle workflow — issue from Vault PKI, back up the
# existing cert, deploy, verify TLS, with automatic rollback on failure.
# This is a workflow job template (multi-step), so it uses the
# aap_workflow_job_launch action and workflow_job_template_id rather than
# the single-job aap_job_launch. The template has ask_inventory_on_launch
# set, so we pass the VM inventory explicitly. Generous timeout to cover
# the full issue/deploy/verify graph. Wired into after_create.
action "aap_workflow_job_launch" "clm_issue_deploy_verify" {
  config {
    workflow_job_template_id            = data.aap_workflow_job_template.clm_issue_deploy_verify.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1800
  }
}

# Ad-hoc vSphere operations — declared so they appear as invocable
# actions in the TFC UI, but intentionally not wired to any
# action_trigger. Workspace developer fires them on demand.
#
# for_each = var.vm_config gives each VM/op pair its own action address
# (e.g. action.aap_job_launch.vsphere_power_off["vm1"]). The CLI's
# -invoke flag can target a single instance:
#
#   terraform apply -invoke='action.aap_job_launch.vsphere_power_off["vm1"]'
#
# extra_vars passes `target_host: <vm hostname>` into the AAP job. The
# matching playbooks (ansible-rhel-post-deploy/playbooks/vsphere-*.yml)
# use `hosts: "{{ target_host | default('all') }}"` so the play scopes
# to that single host. Default-to-all preserves the legacy behaviour
# for any caller that doesn't set the extra_var. The HCP Terraform UI's
# actions list currently collapses for_each instances under one parent
# label — see the Slack draft at /tmp/slack-tfc-actions-feedback.txt
# for the upstream feedback we're filing about this.
action "aap_job_launch" "vsphere_power_off" {
  for_each = var.vm_config
  config {
    job_template_id                     = data.aap_job_template.vsphere_power_off.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
    extra_vars                          = jsonencode({ target_host = each.value.hostname })
  }
}

action "aap_job_launch" "vsphere_power_on" {
  for_each = var.vm_config
  config {
    job_template_id                     = data.aap_job_template.vsphere_power_on.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
    extra_vars                          = jsonencode({ target_host = each.value.hostname })
  }
}

action "aap_job_launch" "vsphere_guest_reboot" {
  for_each = var.vm_config
  config {
    job_template_id                     = data.aap_job_template.vsphere_guest_reboot.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
    extra_vars                          = jsonencode({ target_host = each.value.hostname })
  }
}

action "aap_job_launch" "vsphere_revert_snapshot" {
  for_each = var.vm_config
  config {
    job_template_id                     = data.aap_job_template.vsphere_revert_snapshot.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 900
    extra_vars                          = jsonencode({ target_host = each.value.hostname })
  }
}

action "aap_job_launch" "vsphere_remove_all_snapshots" {
  for_each = var.vm_config
  config {
    job_template_id                     = data.aap_job_template.vsphere_remove_all_snapshots.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 900
    extra_vars                          = jsonencode({ target_host = each.value.hostname })
  }
}
