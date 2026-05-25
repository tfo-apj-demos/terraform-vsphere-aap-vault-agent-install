# Post-VM lifecycle hook
#
# Wires the AAP job-launch actions (declared in actions.tf, looked up
# from JTs in data.tf) to the VM module's lifecycle events.
#
#   after_create — first-time provisioning only: register the host with
#                  RHSM, then install nginx.
#   after_update — drift reconciliation on subsequent applies: re-run the
#                  chrony time-sync only.

resource "terraform_data" "vm_provisioned" {
  input = local.vm_names

  lifecycle {
    # First-time provisioning.
    action_trigger {
      events = [after_create]
      actions = [
        action.aap_job_launch.rhel_register,
        action.aap_job_launch.install_nginx,
      ]
    }

    # Config reconciliation on update.
    action_trigger {
      events = [after_update]
      actions = [
        action.aap_job_launch.chrony_timesync,
      ]
    }
  }
}
