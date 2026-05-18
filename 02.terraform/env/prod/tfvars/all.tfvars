vms = {
  # [1] K8s Masters (3대, local-lvm 적용)
  "k8s-master-01"   = { vm_id = 2131, ip = "172.16.30.31", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35, template_vm_id = 9005, datastore_id = "local-lvm", storage_ip = "10.10.10.201", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"] }
  "k8s-master-02"   = { vm_id = 2232, ip = "172.16.30.32", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35, template_vm_id = 9005, datastore_id = "local-lvm", storage_ip = "10.10.10.202", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"] }
  "k8s-master-03"   = { vm_id = 2333, ip = "172.16.30.33", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35, template_vm_id = 9005, datastore_id = "local-lvm", storage_ip = "10.10.10.203", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-master", "control-plane"] }

  # [2] K8s Workers (플랫폼 1대 + 일반 3대)
  "k8s-worker-plat" = { vm_id = 2440, ip = "172.16.30.40", vlan = 30, bridge = "vmbr0", node = "kosa24", cores = 4, memory = 16384, disk_size = 80, template_vm_id = 9005, storage_ip = "10.10.10.210", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "platform", "ingress", "argocd"] }
  "k8s-worker-01"   = { vm_id = 2145, ip = "172.16.30.45", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.211", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"] }
  "k8s-worker-02"   = { vm_id = 2246, ip = "172.16.30.46", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.212", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"] }
  "k8s-worker-03"   = { vm_id = 2347, ip = "172.16.30.47", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.213", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node"] }

  # [3] DNS Servers
  "dns-01"          = { vm_id = 2211, ip = "172.16.30.11", vlan = 30, bridge = "vmbr0", node = "kosa22", tags = ["infra-dns", "coredns", "etcd"] }
  "dns-02"          = { vm_id = 2312, ip = "172.16.30.12", vlan = 30, bridge = "vmbr0", node = "kosa23", tags = ["infra-dns", "coredns", "etcd"] }

  # [4] Security Servers
  "vault-01"        = { vm_id = 2121, ip = "172.16.30.21", vlan = 30, bridge = "vmbr0", node = "kosa21", tags = ["infra-security", "vault", "pki"] }
  "vault-02"        = { vm_id = 2422, ip = "172.16.30.22", vlan = 30, bridge = "vmbr0", node = "kosa24", tags = ["infra-security", "vault", "pki"] }
  "vault-03"        = { vm_id = 2323, ip = "172.16.30.23", vlan = 30, bridge = "vmbr0", node = "kosa23", tags = ["infra-security", "vault", "pki"] }

  # [5] Load Balancers
  "haproxy-01"      = { vm_id = 2226, ip = "172.16.20.26", vlan = 20, bridge = "vmbr0", node = "kosa22", tags = ["infra-lb", "haproxy", "keepalived"] }
  "haproxy-02"      = { vm_id = 2327, ip = "172.16.20.27", vlan = 20, bridge = "vmbr0", node = "kosa23", tags = ["infra-lb", "haproxy", "keepalived"] }

  # [6] Management & Observability Services
  "nexus-01"        = { vm_id = 2415, ip = "172.16.30.15", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 100, tags = ["service-nexus"] }
  "cicd-01"         = { vm_id = 2455, ip = "172.16.30.55", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 8192, disk_size = 50,  tags = ["service-cicd", "gitlab", "gitlab-runner"] }
  "minio-01"        = { vm_id = 2470, ip = "172.16.30.70", vlan = 30, bridge = "vmbr0", node = "kosa24", memory = 4096, disk_size = 50,  tags = ["service-minio"] }
  "siem-01"         = { vm_id = 2290, ip = "172.16.30.85", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 8192, disk_size = 35,  tags = ["service-siem", "wazuh"] }
  "monitor-01"      = { vm_id = 2396, ip = "172.16.30.91", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 8192, disk_size = 35,  tags = ["service-monitoring", "prometheus", "grafana", "loki"] }
}

# [7] 내부 DNS VIP 설정
vm_nameserver = "172.16.30.10"
