output "vm_name" {
    description = "Name of the created virtual machine"
    value       = module.single_virtual_machine.virtual_machine_name
}

output "vm_ip_address" {
    description = "IP address of the virtual machine"
    value       = module.single_virtual_machine.ip_address
}