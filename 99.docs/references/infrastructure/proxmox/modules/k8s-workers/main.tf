variable "proxmox_nodes" {
  type = list(string)
}

variable "ssh_public_key" {
  type = string
}

variable "vlan_k8s_id" {
  type = number
}

variable "worker_count" {
  type    = number
  default = 6
}

variable "worker_cpu" {
  type    = number
  default = 4
}

variable "worker_memory" {
  type    = number
  default = 8192
}

resource "proxmox_vm_qemu" "k8s_worker" {
  count = var.worker_count
  
  name        = "k8s-worker-${count.index + 1}"
  target_node = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  
  clone       = "ubuntu-22.04-cloudinit"
  
  cores       = var.worker_cpu
  memory      = var.worker_memory
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan_k8s_id
  }
  
  ipconfig0 = "ip=10.0.2.${20 + count.index}/24,gw=10.0.2.1"
  
  sshkeys = var.ssh_public_key
  
  lifecycle {
    ignore_changes = [network]
  }
}

output "worker_ips" {
  value = [for i in range(var.worker_count) : "10.0.2.${20 + i}"]
}

output "worker_names" {
  value = [for vm in proxmox_vm_qemu.k8s_worker : vm.name]
}