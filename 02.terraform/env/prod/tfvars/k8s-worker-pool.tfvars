vms = {
  # 오토스케일링 대비 예비 워커 풀 — 클러스터에 조인하지 않은 상태로 사전 프로비저닝
  # 장애 발생 시 Gitea Actions 트리거 → ansible add-worker.yml --limit <IP> 로 즉시 조인
  "k8s-worker-04" = { vm_id = 2148, ip = "172.16.30.48", vlan = 30, bridge = "vmbr0", node = "kosa21", memory = 4096, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.214", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node", "worker-pool"] }
  "k8s-worker-05" = { vm_id = 2249, ip = "172.16.30.49", vlan = 30, bridge = "vmbr0", node = "kosa22", memory = 4096, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.215", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node", "worker-pool"] }
  "k8s-worker-06" = { vm_id = 2350, ip = "172.16.30.50", vlan = 30, bridge = "vmbr0", node = "kosa23", memory = 4096, disk_size = 35, template_vm_id = 9005, storage_ip = "10.10.10.216", storage_bridge = "vmbr1", storage_cidr = 24, tags = ["k8s-worker", "app-node", "worker-pool"] }
}
