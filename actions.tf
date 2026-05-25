# AAP job-launch actions (templates looked up in data.tf).
# wait_for_completion = true so a job failure fails the apply.

# Provisioning actions — wired into lifecycle.tf.
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

# CLM cert lifecycle (issue -> backup -> deploy -> verify, auto-rollback).
# A workflow job template, so it uses aap_workflow_job_launch +
# workflow_job_template_id; ask_inventory_on_launch is set so we pass the
# inventory explicitly.
action "aap_workflow_job_launch" "clm_issue_deploy_verify" {
  config {
    workflow_job_template_id            = data.aap_workflow_job_template.clm_issue_deploy_verify.id
    inventory_id                        = aap_inventory.vm_inventory.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1800
  }
}

# Ad-hoc vSphere ops — not wired to a trigger; invoked on demand.
# for_each = var.vm_config gives each VM its own action address, keyed by
# the vm_config map key. To target one VM: this is a VCS/cloud workspace,
# so the CLI kicks off a remote plan that you then apply in the TFC UI:
#
#   terraform plan -invoke='action.aap_job_launch.vsphere_power_off["web-server-01"]'
#
# extra_vars sets target_host so the playbook (hosts: "{{ target_host |
# default('all') }}") scopes to that single host.
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
