terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }

  }
}

resource "proxmox_vm_qemu" "vm" {
  name        = var.vm_name
  target_node = var.target_node
  vmid        = var.vmid != 0 ? var.vmid : null

  clone      = var.template_name
  full_clone = true

  boot     = "order=scsi0"
  bootdisk = "scsi0"
  scsihw   = "virtio-scsi-pci"

  memory = var.memory

  cpu {
    cores   = var.cpu_cores
    sockets = 1
  }

  agent = 0

  vga {
    type = "std"
  }

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.storage
    size    = "${var.disk_size}G"
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.storage
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
    tag    = var.vlan_tag
  }

  os_type    = "cloud-init"
  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = var.ssh_public_key
  ipconfig0  = "ip=${var.ip_address},gw=${var.gateway}"
  nameserver = join(" ", var.dns_servers)

  start_at_node_boot = var.onboot

  tags = join(";", var.tags)

  # HA Configuration (Proxmox provider v2.9.x)
  hastate = var.ha_enabled ? var.ha_state : ""

  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}
