vms = {
  # k8s 마스터 노드 (3대)
  "k8s-master-01" = { vm_id = 2130, ip = "172.16.30.30", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-master-02" = { vm_id = 2231, ip = "172.16.30.31", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-master-03" = { vm_id = 2332, ip = "172.16.30.32", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35, template_vm_id = 9005 }

  # k8s 워커 노드 (4대: 플랫폼 1 + 일반 3)
  "k8s-platform-01" = { vm_id = 2440, ip = "172.16.30.40", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-01"   = { vm_id = 2141, ip = "172.16.30.41", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-02"   = { vm_id = 2242, ip = "172.16.30.42", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-03"   = { vm_id = 2343, ip = "172.16.30.43", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35, template_vm_id = 9005 }
}
