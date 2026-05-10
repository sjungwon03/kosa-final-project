variable "proxmox_nodes" {
  type = list(string)
}

variable "ssh_public_key" {
  type = string
}

variable "vlan_k8s_id" {
  type = number
}

variable "vlan_public_id" {
  type = number
}

variable "master_count" {
  type    = number
  default = 3
}

variable "master_cpu" {
  type    = number
  default = 2
}

variable "master_memory" {
  type    = number
  default = 4096
}

resource "proxmox_vm_qemu" "k8s_master" {
  count = var.master_count
  
  name        = "k8s-master-${count.index + 1}"
  target_node = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  
  clone       = "ubuntu-22.04-cloudinit"
  
  cores       = var.master_cpu
  memory      = var.master_memory
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan_k8s_id
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan_public_id
  }
  
  ipconfig0 = "ip=10.0.2.${10 + count.index}/24,gw=10.0.2.1"
  ipconfig1 = "ip=10.0.1.${10 + count.index}/24,gw=10.0.1.1"
  
  sshkeys = var.ssh_public_key
  
  lifecycle {
    ignore_changes = [network]
  }
}

output "master_ips" {
  value = {
    k8s = [for i in range(var.master_count) : "10.0.2.${10 + i}"]
    public = [for i in range(var.master_count) : "10.0.1.${10 + i}"]
  }
}

output "master_names" {
  value = [for vm in proxmox_vm_qemu.k8s_master : vm.name]
}