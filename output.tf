output "vm_names" {
  description = "Map of VM keys to their names"
  value       = local.vm_names
}

output "vm_ip_addresses" {
  description = "Map of VM keys to their IP addresses"
  value       = local.vm_ips
}

output "aap_inventory_id" {
  description = "AAP inventory ID for downstream use"
  value       = aap_inventory.vm_inventory.id
}

output "aap_inventory_name" {
  description = "AAP inventory name for traceability"
  value       = aap_inventory.vm_inventory.name
}
