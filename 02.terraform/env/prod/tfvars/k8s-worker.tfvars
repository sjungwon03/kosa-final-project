vms = {
  "k8s-worker-plat" = { vm_id = 2440, ip = "172.16.30.40", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 8192, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-01"   = { vm_id = 2141, ip = "172.16.30.41", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-02"   = { vm_id = 2242, ip = "172.16.30.42", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-03"   = { vm_id = 2343, ip = "172.16.30.43", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  # 확장 워커 (필요 시 -target으로 개별 생성)
  "k8s-worker-04"   = { vm_id = 2144, ip = "172.16.30.44", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-05"   = { vm_id = 2245, ip = "172.16.30.45", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35, template_vm_id = 9005 }
  "k8s-worker-06"   = { vm_id = 2346, ip = "172.16.30.46", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35, template_vm_id = 9005 }
}
