variable "proxmox_nodes" {
  type = list(string)
}

variable "vlan_public_id" {
  type = number
}

variable "vlan_k8s_id" {
  type = number
}

variable "vlan_db_id" {
  type = number
}

resource "proxmox_vm_qemu" "vlan_bridge" {
  count = length(var.proxmox_nodes)
  
  name        = "vlan-bridge-${var.proxmox_nodes[count.index]}"
  target_node = var.proxmox_nodes[count.index]
  
  clone       = "vlan-bridge-template"
  
  cores       = 1
  memory      = 512
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan_public_id
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan_k8s_id
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan_db_id
  }
  
  lifecycle {
    ignore_changes = [network]
  }
}

output "vlan_bridges" {
  value = [for vm in proxmox_vm_qemu.vlan_bridge : vm.name]
}