vms = {
  "dns1"            = { vm_id = 2211, ip = "172.16.30.11", vlan = 30, bridge = "vmbr0", node = "kosa22" }
  "dns2"            = { vm_id = 2312, ip = "172.16.30.12", vlan = 30, bridge = "vmbr0", node = "kosa23" }
  "vault1"          = { vm_id = 2115, ip = "172.16.30.20", vlan = 30, bridge = "vmbr0", node = "kosa21" }
  "vault2"          = { vm_id = 2416, ip = "172.16.30.21", vlan = 30, bridge = "vmbr0", node = "kosa24" }
  "haproxy1"        = { vm_id = 2226, ip = "172.16.20.26", vlan = 20, bridge = "vmbr0", node = "kosa22" }
  "haproxy2"        = { vm_id = 2327, ip = "172.16.20.27", vlan = 20, bridge = "vmbr0", node = "kosa23" }
  "k8s-master-01"   = { vm_id = 2130, ip = "172.16.30.30", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35 }
  "k8s-master-02"   = { vm_id = 2231, ip = "172.16.30.31", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35 }
  "k8s-master-03"   = { vm_id = 2332, ip = "172.16.30.32", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35 }
  "k8s-worker-plat" = { vm_id = 2440, ip = "172.16.30.40", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 8192, disk_size = 35 }
  "k8s-worker-01"   = { vm_id = 2141, ip = "172.16.30.41", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35 }
  "k8s-worker-02"   = { vm_id = 2242, ip = "172.16.30.42", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35 }
  "k8s-worker-03"   = { vm_id = 2343, ip = "172.16.30.43", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35 }
  "registry"        = { vm_id = 2150, ip = "172.16.30.50", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 50 }
  "cicd"            = { vm_id = 2455, ip = "172.16.30.55", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 35 }
  "siem"            = { vm_id = 2270, ip = "172.16.30.70", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 8192, disk_size = 35 }
  "monitoring"      = { vm_id = 2380, ip = "172.16.30.80", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 8192, disk_size = 35 }
}
