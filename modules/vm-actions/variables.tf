# Per-VM action wrapper for the ad-hoc vSphere ops. Instantiated once per
# VM via `module "vm_actions" { for_each = var.vm_config }` in the root
# module — that gives each VM its own action address namespace
# (module.vm_actions["<vm_key>"].action.aap_job_launch.*), which is the
# only way the HCP Terraform actions UI exposes a per-VM invoke. Using
# `for_each` directly on the action block collapses all instances under
# one parent label in the UI; the module wrapper gets us a distinct
# address per VM.

variable "target_hostname" {
  description = "Short hostname of the VM this action set operates on. Passed to the AAP job as the `target_host` extra_var so the playbook scopes its `hosts:` pattern to a single VM."
  type        = string
}

variable "inventory_id" {
  description = "AAP inventory id all five actions launch against."
  type        = string
}

variable "power_off_jt_id" {
  description = "AAP job_template id for vsphere-power-off."
  type        = string
}

variable "power_on_jt_id" {
  description = "AAP job_template id for vsphere-power-on."
  type        = string
}

variable "guest_reboot_jt_id" {
  description = "AAP job_template id for vsphere-guest-reboot."
  type        = string
}

variable "revert_snapshot_jt_id" {
  description = "AAP job_template id for vsphere-revert-snapshot."
  type        = string
}

variable "remove_all_snapshots_jt_id" {
  description = "AAP job_template id for vsphere-remove-all-snapshots."
  type        = string
}
