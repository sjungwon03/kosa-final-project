output "vm_id" {
  description = "VM ID"
  value       = proxmox_vm_qemu.vm.vmid
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_vm_qemu.vm.name
}

output "vm_ip" {
  description = "VM IP address"
  value       = var.ip_address
}

output "vm_ha_state" {
  description = "VM HA state"
  value       = var.ha_enabled ? var.ha_state : "disabled"
}