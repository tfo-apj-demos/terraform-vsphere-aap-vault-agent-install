locals {
  # The wrapped playbooks read `target_host` and use it as the play's
  # `hosts:` pattern (defaulting to `all` when absent). Each module
  # instance hard-binds the value to its own VM's hostname so the
  # invocation always scopes to a single VM.
  extra_vars = jsonencode({ target_host = var.target_hostname })
}

action "aap_job_launch" "vsphere_power_off" {
  config {
    job_template_id                     = var.power_off_jt_id
    inventory_id                        = var.inventory_id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
    extra_vars                          = local.extra_vars
  }
}

action "aap_job_launch" "vsphere_power_on" {
  config {
    job_template_id                     = var.power_on_jt_id
    inventory_id                        = var.inventory_id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
    extra_vars                          = local.extra_vars
  }
}

action "aap_job_launch" "vsphere_guest_reboot" {
  config {
    job_template_id                     = var.guest_reboot_jt_id
    inventory_id                        = var.inventory_id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
    extra_vars                          = local.extra_vars
  }
}

action "aap_job_launch" "vsphere_revert_snapshot" {
  config {
    job_template_id                     = var.revert_snapshot_jt_id
    inventory_id                        = var.inventory_id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 900
    extra_vars                          = local.extra_vars
  }
}

action "aap_job_launch" "vsphere_remove_all_snapshots" {
  config {
    job_template_id                     = var.remove_all_snapshots_jt_id
    inventory_id                        = var.inventory_id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 900
    extra_vars                          = local.extra_vars
  }
}
