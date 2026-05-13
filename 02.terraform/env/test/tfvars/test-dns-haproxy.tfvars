vms = {
  "dns1"     = { vm_id = 12211, ip = "172.16.30.111", vlan = 30, bridge = "vmbr0", node = "kosa22" }
  "dns2"     = { vm_id = 12312, ip = "172.16.30.112", vlan = 30, bridge = "vmbr0", node = "kosa23" }
  "haproxy1" = { vm_id = 12226, ip = "172.16.20.126", vlan = 20, bridge = "vmbr0", node = "kosa22" }
  "haproxy2" = { vm_id = 12327, ip = "172.16.20.127", vlan = 20, bridge = "vmbr0", node = "kosa23" }
}
