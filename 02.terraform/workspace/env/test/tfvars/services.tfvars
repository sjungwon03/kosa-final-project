vms = {
  "registry"   = { vm_id = 12150, ip = "172.16.30.150", vlan = 30, bridge = "vmbr0", node = "kosa21", tags = ["service-registry", "harbor"] }
  "cicd"       = { vm_id = 12455, ip = "172.16.30.155", vlan = 30, bridge = "vmbr0", node = "kosa24", tags = ["service-cicd", "gitlab", "gitlab-runner"] }
  "siem"       = { vm_id = 12270, ip = "172.16.30.170", vlan = 30, bridge = "vmbr0", node = "kosa22", tags = ["service-siem", "wazuh"] }
  "monitoring" = { vm_id = 12380, ip = "172.16.30.180", vlan = 30, bridge = "vmbr0", node = "kosa23", tags = ["service-monitoring", "prometheus", "grafana", "loki"] }
}