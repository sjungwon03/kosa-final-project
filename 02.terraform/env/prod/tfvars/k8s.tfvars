vms = {
  # k8s 마스터 노드 (3대) — VIP: 172.16.30.30 (Keepalived, VLAN 30)
  "k8s-master-01" = { vm_id = 2131, ip = "172.16.30.31", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.200", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa21", memory = 4096, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005 }
  "k8s-master-02" = { vm_id = 2232, ip = "172.16.30.32", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.201", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa22", memory = 4096, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005 }
  "k8s-master-03" = { vm_id = 2333, ip = "172.16.30.33", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.202", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa23", memory = 4096, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005 }

  # k8s 워커 노드 (4대: 플랫폼 1 + 일반 3)
  "k8s-worker-plat" = { vm_id = 2440, ip = "172.16.30.40", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.210", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa24", cores = 12, memory = 16384, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-01"   = { vm_id = 2145, ip = "172.16.30.45", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.211", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa21", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-02"   = { vm_id = 2246, ip = "172.16.30.46", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.212", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa22", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-03"   = { vm_id = 2347, ip = "172.16.30.47", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.213", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa23", memory = 4096, disk_size = 35, template_vm_id = 9005 }
}
