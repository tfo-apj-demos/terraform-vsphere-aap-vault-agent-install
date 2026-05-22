# Post-VM lifecycle hook
#
# Fires the core after_create stack (declared in actions.tf, looked up
# from JTs in data.tf) once the VM module finishes. Idempotent — same
# action set runs on after_update so config drift is reconciled.

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
        action.aap_job_launch.vault_agent,
        action.aap_job_launch.install_nginx,
      ]
    }

  }
}
