vms = {
  "k8s-master-01"   = { vm_id = 12130, ip = "172.16.30.130", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, datastore_id = "local-lvm", template_vm_id = 9005, storage_ip = "10.10.10.230", storage_bridge = "vmbr1", storage_cidr = 24 }
  "k8s-master-02"   = { vm_id = 12231, ip = "172.16.30.131", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, datastore_id = "local-lvm", template_vm_id = 9005, storage_ip = "10.10.10.231", storage_bridge = "vmbr1", storage_cidr = 24 }
  "k8s-worker-plat" = { vm_id = 12440, ip = "172.16.30.140", vlan = 30, bridge = "vmbr0", node = "kosa24", cores = 12, memory = 4096, template_vm_id = 9005, storage_ip = "10.10.10.240", storage_bridge = "vmbr1", storage_cidr = 24 }
  "k8s-worker-01"   = { vm_id = 12141, ip = "172.16.30.141", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 12288, template_vm_id = 9005, storage_ip = "10.10.10.241", storage_bridge = "vmbr1", storage_cidr = 24 }
  "k8s-worker-02"   = { vm_id = 12242, ip = "172.16.30.142", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 12288, template_vm_id = 9005, storage_ip = "10.10.10.242", storage_bridge = "vmbr1", storage_cidr = 24 }
}
