vms = {
  "haproxy1" = { vm_id = 2226, ip = "172.16.20.26", vlan = 20, bridge = "vmbr0", node = "kosa22", tags = ["infra-lb", "haproxy", "keepalived"] }
  "haproxy2" = { vm_id = 2327, ip = "172.16.20.27", vlan = 20, bridge = "vmbr0", node = "kosa23", tags = ["infra-lb", "haproxy", "keepalived"] }
}
