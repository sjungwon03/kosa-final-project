vms = {
  # [1] K8s Masters (3대, local-lvm 적용)
  "k8s-master-01"   = { vm_id = 2131, ip = "172.16.30.31", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 8192, disk_size = 35, template_vm_id = 9005, datastore_id = "local-lvm", storage_ip = "10.10.10.201", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"], protection = true }
  "k8s-master-02"   = { vm_id = 2232, ip = "172.16.30.32", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 8192, disk_size = 35, template_vm_id = 9005, datastore_id = "local-lvm", storage_ip = "10.10.10.202", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"], protection = true }
  "k8s-master-03"   = { vm_id = 2333, ip = "172.16.30.33", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 8192, disk_size = 35, template_vm_id = 9005, datastore_id = "local-lvm", storage_ip = "10.10.10.203", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"], protection = true }

  # [2] K8s Workers (플랫폼 1대 + 일반 3대)
  "k8s-worker-plat" = { vm_id = 2440, ip = "172.16.30.40", vlan = 30, bridge = "vmbr0", node = "kosa24", cores = 12, memory = 12288, disk_size = 80, template_vm_id = 9005, storage_ip = "10.10.10.210", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "platform", "ingress", "argocd"], protection = true }
  "k8s-worker-01"   = { vm_id = 2145, ip = "172.16.30.45", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 8192, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.211", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"], protection = true }
  "k8s-worker-02"   = { vm_id = 2246, ip = "172.16.30.46", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 8192, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.212", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"], protection = true }
  "k8s-worker-03"   = { vm_id = 2347, ip = "172.16.30.47", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 8192, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.213", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"], protection = true }

  # [3] DNS Servers
  "dns-01"          = { vm_id = 2211, ip = "172.16.30.11", vlan = 30, bridge = "vmbr0", node = "kosa22", tags = ["infra-dns", "coredns", "etcd"], protection = true }
  "dns-02"          = { vm_id = 2312, ip = "172.16.30.12", vlan = 30, bridge = "vmbr0", node = "kosa23", tags = ["infra-dns", "coredns", "etcd"], protection = true }

  # [4] Security Servers
  "vault-01"        = { vm_id = 2221, ip = "172.16.30.21", vlan = 30, bridge = "vmbr0", node = "kosa22", tags = ["infra-security", "vault", "pki"], protection = true }
  "vault-02"        = { vm_id = 2322, ip = "172.16.30.22", vlan = 30, bridge = "vmbr0", node = "kosa23", tags = ["infra-security", "vault", "pki"], protection = true }
  "vault-03"        = { vm_id = 2423, ip = "172.16.30.23", vlan = 30, bridge = "vmbr0", node = "kosa24", tags = ["infra-security", "vault", "pki"], protection = true }

  # [5] Load Balancers
  "haproxy-01"      = { vm_id = 2226, ip = "172.16.20.26", vlan = 20, bridge = "vmbr0", node = "kosa22", tags = ["infra-lb", "haproxy", "keepalived"], protection = true }
  "haproxy-02"      = { vm_id = 2327, ip = "172.16.20.27", vlan = 20, bridge = "vmbr0", node = "kosa23", tags = ["infra-lb", "haproxy", "keepalived"], protection = true }

  # [6] Management & Observability Services
  "nexus-01"        = { vm_id = 2415, ip = "172.16.30.15", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 100, tags = ["service-nexus"], protection = true }
  "cicd-01"         = { vm_id = 2355, ip = "172.16.30.55", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 12288, disk_size = 100, tags = ["service-cicd", "gitlab", "gitlab-runner"], protection = true }
  "minio-01"        = { vm_id = 2470, ip = "172.16.30.70", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 50,  tags = ["service-minio"], protection = true }
  "siem-01"         = { vm_id = 2285, ip = "172.16.30.85", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 8192, disk_size = 50,  tags = ["service-siem", "wazuh"], protection = true }
  "monitor-01"      = { vm_id = 2196, ip = "172.16.30.91", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 8192, disk_size = 35,  tags = ["service-monitoring", "prometheus", "grafana", "loki"], protection = true }
  "testsec-01"      = { vm_id = 2275, ip = "172.16.30.75", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 2048, disk_size = 10,  tags = ["service-testsec"] }
}

# [7] 내부 DNS VIP 설정
vm_nameserver = "172.16.30.10"
