terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu" {
  for_each  = var.vms
  name      = each.key
  node_name = each.value.node
  vm_id     = each.value.vm_id

  clone {
    vm_id     = var.template_vm_id
    node_name = var.template_node
    full      = true
  }

  cpu {
    cores   = var.vm_cores
    sockets = 1
    type    = "host"
    numa    = true
  }

  memory {
    dedicated = var.vm_memory
  }

  network_device {
    bridge   = each.value.bridge
    vlan_id  = each.value.vlan
    model    = "virtio"
    firewall = false
  }

  disk {
    datastore_id = "rbd-storage"
    interface    = "scsi0"
    size         = var.vm_disk_size
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  initialization {
    dns {
      servers = split(" ", var.vm_nameserver)
    }
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "172.16.${each.value.vlan}.1"
      }
    }
  }

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  vga {
    type = "std"
  }
}
