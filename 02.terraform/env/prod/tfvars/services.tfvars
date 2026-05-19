vms = {
  "registry"   = { vm_id = 2150, ip = "172.16.30.50", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 50 }
  "cicd"       = { vm_id = 2455, ip = "172.16.30.55", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 35 }
  "siem"       = { vm_id = 2270, ip = "172.16.30.70", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 8192, disk_size = 35 }
  "monitoring" = { vm_id = 2380, ip = "172.16.30.80", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 8192, disk_size = 35 }
}
