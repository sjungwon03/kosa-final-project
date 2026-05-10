variable "proxmox_nodes" {
  type = list(string)
}

variable "ssh_public_key" {
  type = string
}

variable "vlan_db_id" {
  type = number
}

variable "db_count" {
  type    = number
  default = 3
}

variable "db_cpu" {
  type    = number
  default = 2
}

variable "db_memory" {
  type    = number
  default = 4096
}

resource "proxmox_vm_qemu" "mysql_db" {
  count = var.db_count
  
  name        = "mysql-db-${count.index + 1}"
  target_node = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
  
  clone       = "ubuntu-22.04-cloudinit"
  
  cores       = var.db_cpu
  memory      = var.db_memory
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = var.vlan_db_id
  }
  
  ipconfig0 = "ip=10.0.3.${10 + count.index}/24,gw=10.0.3.1"
  
  sshkeys = var.ssh_public_key
  
  lifecycle {
    ignore_changes = [network]
  }
}

output "database_ips" {
  value = [for i in range(var.db_count) : "10.0.3.${10 + i}"]
}

output "database_names" {
  value = [for vm in proxmox_vm_qemu.mysql_db : vm.name]
}