vms = {
  # k8s 마스터 1대
  "k8s-master-01" = { vm_id = 12130, ip = "172.16.30.130", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, template_vm_id = 9005 }

  # k8s 워커 1대
  "k8s-worker-01" = { vm_id = 12141, ip = "172.16.30.141", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, template_vm_id = 9005 }
}
