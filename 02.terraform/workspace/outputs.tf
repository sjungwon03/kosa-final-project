output "vm_names" {
  value = { for k, v in proxmox_virtual_environment_vm.ubuntu : k => v.name }
}

output "vm_ids" {
  value = { for k, v in proxmox_virtual_environment_vm.ubuntu : k => v.vm_id }
}

output "vm_ipv4_addresses" {
  value = { for k, v in proxmox_virtual_environment_vm.ubuntu : k => v.ipv4_addresses }
}
