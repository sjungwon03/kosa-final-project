terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 2.9.0"
    }
  }
}

resource "proxmox_vm_qemu" "vm" {
  name        = var.vm_name
  target_node = var.target_node

  clone       = var.template_vmid
  full_clone  = true

  cores   = var.cpu_cores
  sockets = 1
  memory  = var.memory

  agent = 1

  disk {
    slot    = 0
    type    = "disk"
    storage = var.storage
    size    = "${var.disk_size}G"
    iothread = 1
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = var.vlan_tag
  }

  os_type    = "cloud-init"
  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.ssh_public_key
  ipconfig0  = "ip=${var.ip_address},gw=${var.gateway}"

  nameserver = join(";", var.dns_servers)

  onboot = var.onboot

  tags = join(";", var.tags)

  # HA Configuration (Proxmox provider v2.9.x)
  hastate = var.ha_enabled ? var.ha_state : ""

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}