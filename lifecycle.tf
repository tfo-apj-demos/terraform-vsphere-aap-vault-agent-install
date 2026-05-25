# Fires AAP actions on the VM module's lifecycle events:
#   after_create — first provisioning: register, install nginx, CLM cert workflow
#   after_update — drift reconciliation: chrony only

resource "terraform_data" "vm_provisioned" {
  input = local.vm_names

  lifecycle {
    action_trigger {
      events = [after_create]
      actions = [
        action.aap_job_launch.rhel_register,
        action.aap_job_launch.install_nginx,
        action.aap_workflow_job_launch.clm_issue_deploy_verify,
      ]
    }

    action_trigger {
      events = [after_update]
      actions = [
        action.aap_job_launch.chrony_timesync,
      ]
    }
  }
}
