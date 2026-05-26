# VM 명세

- Terraform tfvars 및 Ansible inventory 기준으로 이 파일을 유지함
- 하드웨어 사양 변경 시 Terraform tfvars와 이 파일을 동시에 수정해야 함

---

## 수동 구성

| 호스트 | VMID | VM명 | IP | DNS | CPU | 메모리(MB) | 디스크(GB) | 스토리지 | 주요 스택 |
|---|---|---|---|---|---|---|---|---|---|
| kosa21 | 2105 | pfSense-01 | 172.16.20.5 | firewall.edge.local | 2 | 8192 | 32 | rbd-storage | 방화벽, NAT, WireGuard VPN |
| kosa22 | 2207 | control-01 | 172.16.30.7 | ctrl.mgmt.local | 2 | 2048 | 10 | rbd-storage | Terraform, Ansible, etcd |

---

## 자동 구성 (prod)

| 호스트 | VMID | VM명 | IP | DNS | CPU | 메모리(MB) | 디스크(GB) | 스토리지 | 주요 스택 |
|---|---|---|---|---|---|---|---|---|---|
| - | - | **DNS VIP** | 172.16.30.10 | dns.svc.local | - | - | - | - | Keepalived Float IP |
| kosa22 | 2211 | dns-01   | 172.16.30.11 | dns-01.svc.local | 2 | 2048 | 10 | rbd-storage | Keepalived, CoreDNS, etcd |
| kosa23 | 2312 | dns-02   | 172.16.30.12 | dns-02.svc.local | 2 | 2048 | 10 | rbd-storage | Keepalived, CoreDNS, etcd |
| kosa24 | 2415 | nexus-01 | 172.16.30.15 | nexus.mgmt.local | 2 | 4096 | 100 | rbd-storage | Nexus (apt mirror, binary) |
| - | - | **Vault VIP** | 172.16.30.20 | vault.sec.local | - | - | - | - | Keepalived Float IP |
| kosa22 | 2221 | vault-01 | 172.16.30.21 | vault-01.sec.local | 2 | 2048 | 10 | rbd-storage | HashiCorp Vault/PKI |
| kosa23 | 2322 | vault-02 | 172.16.30.22 | vault-02.sec.local | 2 | 2048 | 10 | rbd-storage | HashiCorp Vault/PKI |
| kosa24 | 2423 | vault-03 | 172.16.30.23 | vault-03.sec.local | 2 | 2048 | 10 | rbd-storage | HashiCorp Vault/PKI |
| - | - | **HAProxy VIP** | 172.16.20.25 | haproxy.svc.local | - | - | - | - | Keepalived Float IP |
| kosa22 | 2226 | haproxy-01 | 172.16.20.26 | haproxy-01.svc.local | 2 | 2048 | 10 | rbd-storage | Keepalived, HAProxy |
| kosa23 | 2327 | haproxy-02 | 172.16.20.27 | haproxy-02.svc.local | 2 | 2048 | 10 | rbd-storage | Keepalived, HAProxy |
| - | - | **K8s VIP** | 172.16.30.30 | - | - | - | - | - | API Server HA |
| kosa21 | 2131 | k8s-master-01 | 172.16.30.31 | master-01.k8s.local | 2 | 8192 | 35 | **local-lvm** | Keepalived, kubeadm |
| kosa22 | 2232 | k8s-master-02 | 172.16.30.32 | master-02.k8s.local | 2 | 6144 | 35 | **local-lvm** | Keepalived, kubeadm |
| kosa23 | 2333 | k8s-master-03 | 172.16.30.33 | master-03.k8s.local | 2 | 6144 | 35 | **local-lvm** | Keepalived, kubeadm |
| kosa24 | 2440 | k8s-worker-plat | 172.16.30.40 | node-plat.k8s.local | 12 | 20480 | 80 | rbd-storage | Ingress, ArgoCD |
| kosa21 | 2145 | k8s-worker-01 | 172.16.30.45 | node-01.k8s.local | 2 | 12288 | 35 | rbd-storage | kubelet |
| kosa22 | 2246 | k8s-worker-02 | 172.16.30.46 | node-02.k8s.local | 2 | 12288 | 35 | rbd-storage | kubelet |
| kosa23 | 2347 | k8s-worker-03 | 172.16.30.47 | node-03.k8s.local | 2 | 12288 | 35 | rbd-storage | kubelet |
| kosa23 | 2355 | cicd-01 | 172.16.30.55 | cicd.mgmt.local | 2 | 8192 | 50 | rbd-storage | GitLab Runner |
| kosa24 | 2470 | minio-01 | 172.16.30.70 | minio.mgmt.local | 2 | 4096 | 50 | rbd-storage | MinIO |
| kosa22 | 2275 | testsec-01 | 172.16.30.75 | stress.mgmt.local | 2 | 2048 | 10 | rbd-storage | stress-ng, nmap, hping3, wrk |
| kosa22 | 2285 | siem-01 | 172.16.30.85 | siem.mgmt.local | 2 | 8192 | 35 | rbd-storage | Wazuh |
| - | - | **PLG VIP** | 172.16.30.90 | monitor.mgmt.local | - | - | - | - | Keepalived Float IP (예정) |
| kosa21 | 2191 | monitor-01 | 172.16.30.91 | monitor.mgmt.local | 2 | 8192 | 35 | rbd-storage | Prometheus, Grafana, Loki |

[주의]
- siem은 2290으로 배포됨 (2285)
- monitor은 2196으로 배포됨 (2191)

**VIP**

| 서비스 | VIP | DNS | 비고 |
|---|---|---|---|
| DNS VIP     | 172.16.30.10 | dns.svc.local | CoreDNS HA |
| Vault VIP   | 172.16.30.20 | vault.sec.local | HashiCorp Vault HA |
| HAProxy VIP | 172.16.20.25 | haproxy.svc.local | 외부 접점 |
| K8s VIP     | 172.16.30.30 | - | API Server HA |
| PLG VIP     | 172.16.30.90 | monitor.mgmt.local | 모니터링 HA (예정) |

---

## 자동 구성 (test)

| 호스트 | VMID | VM명 | IP | DNS | CPU | 메모리(MB) | 디스크(GB) | 스토리지 | 주요 스택 |
|---|---|---|---|---|---|---|---|---|---|
| kosa21 | 12130 | k8s-master-01 | 172.16.30.130 | test-master-01.k8s.local | 2 | 4096 | 10 | **local-lvm** | 마스터 노드 |
| kosa22 | 12231 | k8s-master-02 | 172.16.30.131 | test-master-02.k8s.local | 2 | 4096 | 10 | **local-lvm** | 마스터 노드 |
| kosa24 | 12440 | k8s-worker-plat | 172.16.30.140 | test-node-plat.k8s.local | 12 | 4096 | 10 | rbd-storage | 플랫폼 워커 |
| kosa21 | 12141 | k8s-worker-01 | 172.16.30.141 | test-node-01.k8s.local | 2 | 12288 | 10 | rbd-storage | 워커 노드 |
| kosa22 | 12242 | k8s-worker-02 | 172.16.30.142 | test-node-02.k8s.local | 2 | 12288 | 10 | rbd-storage | 워커 노드 |
| kosa22 | 12211 | dns1 | 172.16.30.111 | test-dns-01.svc.local | 2 | 2048 | 10 | rbd-storage | CoreDNS |
| kosa21 | 12115 | vault1 | 172.16.30.121 | test-vault-01.sec.local | 2 | 2048 | 10 | rbd-storage | HashiCorp Vault |
