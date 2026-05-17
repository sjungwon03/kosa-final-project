vms = {
  "k8s-master-01" = { vm_id = 2130, ip = "172.16.30.30", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.200", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa21", memory = 4096, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005 }
  "k8s-master-02" = { vm_id = 2231, ip = "172.16.30.31", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.201", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa22", memory = 4096, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005 }
  "k8s-master-03" = { vm_id = 2332, ip = "172.16.30.32", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.202", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa23", memory = 4096, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005 }
}
