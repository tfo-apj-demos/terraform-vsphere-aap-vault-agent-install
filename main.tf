# vSphere VM build driven by HCP Terraform, provisioned via AAP.
# Lifecycle action wiring lives in lifecycle.tf.

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
