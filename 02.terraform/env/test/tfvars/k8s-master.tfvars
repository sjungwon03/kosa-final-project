vms = {
  "k8s-master-01" = { vm_id = 12130, ip = "172.16.30.130", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.230", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa21", memory = 4096, datastore_id = "local-lvm", template_vm_id = 9005 }
}
