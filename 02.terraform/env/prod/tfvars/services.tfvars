vms = {
  "nexus-01"   = { vm_id = 2415, ip = "172.16.30.15", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 100, tags = ["service-nexus"] }
  "cicd-01"    = { vm_id = 2355, ip = "172.16.30.55", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 8192, disk_size = 50,  tags = ["service-cicd", "gitlab", "gitlab-runner"] }
  "minio-01"   = { vm_id = 2470, ip = "172.16.30.70", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 50,  tags = ["service-minio"] }
  "siem-01"    = { vm_id = 2290, ip = "172.16.30.85", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 8192, disk_size = 35,  tags = ["service-siem", "wazuh"] }
  "monitor-01" = { vm_id = 2196, ip = "172.16.30.91", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 8192, disk_size = 35,  tags = ["service-monitoring", "prometheus", "grafana", "loki"] }
}
