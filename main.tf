# HCP Terraform: vSphere VM Build with Ansible Automation Platform and HashiCorp Vault Agent
#
# File layout:
#   main.tf       — architecture commentary + locals
#   inventory.tf  — AAP inventory, groups, per-host registration
#   vm.tf         — the single_virtual_machine module (per-VM)
#   data.tf       — AAP job_template data-source lookups
#   actions.tf    — action.aap_job_launch blocks (lifecycle + ad-hoc)
#   lifecycle.tf  — terraform_data.vm_provisioned (after_create / after_update trigger)
#   provider.tf   — providers, cloud{} backend, required versions
#   variables.tf  — input variables
#   output.tf     — workspace outputs
#
# Lifecycle wiring:
#   aap_host.vm_hosts            → before_create / before_update (per-VM)
#   terraform_data.vm_provisioned → after_create  / after_update
#
# aap_host is independent of the VM module (uses FQDN for ansible_host).
# Putting before_* on aap_host means the action triggers don't need a
# depends_on link into the VM module — which is important because that
# explicit dep forces the upstream tags-submodule data sources to defer to
# apply time, and the comprehension `[for tag in module.tags : tag.tag_id]`
# in app.terraform.io/tfo-apj-demos/virtual-machine/vsphere v2.0.2 then
# fails plan-time schema validation with "Null value found in list".
#
# vSphere ops (power_off, power_on, guest_reboot, revert_snapshot,
# remove_all_snapshots) are declared as actions but not bound to any
# lifecycle trigger — they're available as ad-hoc operations from the
# TFC UI for the workspace developer to invoke on demand. They're
# for_each'd over var.vm_config so each VM/op pair gets its own action
# address (e.g. action.aap_job_launch.vsphere_power_off["vm1"]) — the
# CLI -invoke flag can target a single instance:
#
#   terraform apply -invoke='action.aap_job_launch.vsphere_power_off["vm1"]'
#
# The HCP Terraform UI's actions list currently collapses for_each
# instances to one entry per label and fires all of them on click.

locals {
  vm_names = {
    for vm_key, vm_value in module.single_virtual_machine :
    vm_key => vm_value.virtual_machine_name
  }
  vm_ips = {
    for vm_key, vm_value in module.single_virtual_machine :
    vm_key => vm_value.ip_address
  }
}
