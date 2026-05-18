vms = {
  "k8s-worker-plat" = { vm_id = 2440, ip = "172.16.30.40", vlan = 30, bridge = "vmbr0", node = "kosa24", cores = 4, memory = 16384, disk_size = 80, template_vm_id = 9005, storage_ip = "10.10.10.210", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "platform", "ingress", "argocd"] }
  "k8s-worker-01"   = { vm_id = 2145, ip = "172.16.30.45", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 12288, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.211", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"] }
  "k8s-worker-02"   = { vm_id = 2246, ip = "172.16.30.46", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 12288, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.212", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"] }
  "k8s-worker-03"   = { vm_id = 2347, ip = "172.16.30.47", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 12288, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.213", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"] }
}
