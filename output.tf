output "vm_name" {
    description = "Name of the created virtual machine"
    value       = vsphere_virtual_machine.vm.name
}

output "vm_id" {
    description = "ID of the created virtual machine"
    value       = vsphere_virtual_machine.vm.id
}

output "vm_ip_address" {
    description = "IP address of the virtual machine"
    value       = vsphere_virtual_machine.vm.default_ip_address
}

output "vm_guest_ip_addresses" {
    description = "All IP addresses assigned to the virtual machine"
    value       = vsphere_virtual_machine.vm.guest_ip_addresses
}

output "vm_uuid" {
    description = "UUID of the virtual machine"
    value       = vsphere_virtual_machine.vm.uuid
}

output "vm_moid" {
    description = "Managed object ID of the virtual machine"
    value       = vsphere_virtual_machine.vm.moid
}

output "vm_fqdn" {
    description = "Fully qualified domain name of the virtual machine"
    value       = vsphere_virtual_machine.vm.guest_ip_addresses != null ? "${vsphere_virtual_machine.vm.name}.${var.vm_config.ad_domain}" : null
}