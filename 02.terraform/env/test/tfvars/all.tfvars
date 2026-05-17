vms = {
  "dns1"            = { vm_id = 12211, ip = "172.16.30.111", vlan = 30, bridge = "vmbr0", node = "kosa22" }
  "dns2"            = { vm_id = 12312, ip = "172.16.30.112", vlan = 30, bridge = "vmbr0", node = "kosa23" }
  "vault1"          = { vm_id = 12115, ip = "172.16.30.120", vlan = 30, bridge = "vmbr0", node = "kosa21" }
  "vault2"          = { vm_id = 12416, ip = "172.16.30.121", vlan = 30, bridge = "vmbr0", node = "kosa24" }
  "haproxy1"        = { vm_id = 12226, ip = "172.16.20.126", vlan = 20, bridge = "vmbr0", node = "kosa22" }
  "haproxy2"        = { vm_id = 12327, ip = "172.16.20.127", vlan = 20, bridge = "vmbr0", node = "kosa23" }
  "k8s-master-01"   = { vm_id = 12130, ip = "172.16.30.130", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.230", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa21", memory = 4096, template_vm_id = 9005 }
  "k8s-master-02"   = { vm_id = 12231, ip = "172.16.30.131", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.231", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa22", memory = 4096, template_vm_id = 9005 }
  "k8s-master-03"   = { vm_id = 12332, ip = "172.16.30.132", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.232", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa23", memory = 4096, template_vm_id = 9005 }
  "k8s-worker-plat" = { vm_id = 12440, ip = "172.16.30.140", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.240", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa24", cores = 12, memory = 4096, template_vm_id = 9005 }
  "k8s-worker-01"   = { vm_id = 12141, ip = "172.16.30.141", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.241", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa21", memory = 4096, template_vm_id = 9005 }
  "k8s-worker-02"   = { vm_id = 12242, ip = "172.16.30.142", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.242", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa22", memory = 4096, template_vm_id = 9005 }
  "k8s-worker-03"   = { vm_id = 12343, ip = "172.16.30.143", vlan = 30, bridge = "vmbr0", storage_ip = "10.10.10.243", storage_bridge = "vmbr1", storage_cidr = 24, node = "kosa23", memory = 4096, template_vm_id = 9005 }
  "registry"        = { vm_id = 12150, ip = "172.16.30.150", vlan = 30, bridge = "vmbr0", node = "kosa21" }
  "cicd"            = { vm_id = 12455, ip = "172.16.30.155", vlan = 30, bridge = "vmbr0", node = "kosa24" }
  "siem"            = { vm_id = 12270, ip = "172.16.30.170", vlan = 30, bridge = "vmbr0", node = "kosa22" }
  "monitoring"      = { vm_id = 12380, ip = "172.16.30.180", vlan = 30, bridge = "vmbr0", node = "kosa23" }
}

# [7] 내부 DNS VIP 설정
vm_nameserver = "172.16.30.10"
