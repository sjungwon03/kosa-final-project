vms = {
  "k8s-master-01" = { vm_id = 2131, ip = "172.16.30.31", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 8192, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005, storage_ip = "10.10.10.201", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"] }
  "k8s-master-02" = { vm_id = 2232, ip = "172.16.30.32", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 8192, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005, storage_ip = "10.10.10.202", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"] }
  "k8s-master-03" = { vm_id = 2333, ip = "172.16.30.33", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 8192, disk_size = 35, datastore_id = "local-lvm", template_vm_id = 9005, storage_ip = "10.10.10.203", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"] }
}
