# Ansible

컨트롤 노드 VM 생성 및 Ansible 플레이북 관리

**사용 목적**
- 초기 구축: 소프트웨어 설치, 클러스터 초기화
- 운영 자동화: 설정 변경, 노드 추가, 패치, 복구

> 초기 구축(`playbooks/`)과 운영(`playbooks/ops/`)으로 구분 (문서 참고)

문서 목록
- [구축 가이드 (EXAMPLES.md)](./EXAMPLES.md)
- [운영 가이드 (OPERATIONS.md)](./OPERATIONS.md)
- [트러블슈팅 가이드 (TROUBLESHOOTING.md)](./TROUBLESHOOTING.md)

**파이프라인 (실행 순서)**

| 순서 | 폴더 | 내용 | 실행 위치 |
|---|---|---|---|
| 1 | 00.scripts | 베이스 템플릿(9000) 생성 | Proxmox 호스트 |
| 2 | 01.packer | 공통 템플릿(9003, 9005) 생성 | 빌드 서버 |
| 3 | **03.ansible** | **컨트롤 노드 VM 생성** | **Proxmox 호스트** |
| 4 | 02.terraform | VM 프로비저닝 | 컨트롤 노드 |
| 5 | **03.ansible** | **Ansible 플레이북 실행** | **컨트롤 노드** |

**디렉토리 구성**

```
03.ansible/
├── 03-create-control-node.sh   # 컨트롤 노드 VM 생성
├── 03-deploy-to-control.sh     # 로컬 → 컨트롤 노드로 설정 파일 배포
├── .env                        # VM 설정 (gitignore)
└── workspace/                  # Ansible 플레이북 및 롤
    ├── keys/                   # 사용자 SSH 공개키 (*.pub)
    ├── ansible-run.sh          # 앤서블 플레이북 실행
    ├── ansible.cfg             # 앤서블 플레이북 설정
    ├── group_vars/
    │   └── all.yml             # 전체 환경 공통 변수
    ├── roles/                   # 환경 공통 롤
    │   ├── common/             # 전체 VM 공통 기본 설정
    │   ├── docker_base/        # 도커 엔진 설치
    │   ├── dns/                # CoreDNS + etcd + Keepalived
    │   ├── vault/              # HashiCorp Vault
    │   ├── haproxy/            # HAProxy + Keepalived
    │   ├── nexus/              # Nexus (apt mirror, raw binary, docker registry)
    │   ├── minio/              # MinIO (Terraform Backend S3)
    │   ├── k8s_common/         # k8s 공통 설정
    │   ├── k8s_master/         # k8s 마스터 노드
    │   ├── k8s_worker/         # k8s 워커 노드
    │   ├── percona_pxc/        # Percona XtraDB Cluster
    │   ├── proxysql/           # ProxySQL + Keepalived VIP
    │   ├── cicd/               # Gitea
    │   ├── siem/               # Wazuh
    │   └── monitor/            # 모니터링 (Grafana, Loki 등)
    ├── playbooks/
    │   ├── site.yml            # 전체 실행
    │   ├── dns.yml
    │   ├── vault.yml
    │   ├── haproxy.yml
    │   ├── registry.yml
    │   ├── minio.yml
    │   ├── k8s.yml
    │   ├── db.yml
    │   ├── cicd.yml
    │   ├── siem.yml
    │   ├── monitor.yml
    │   └── ops/                # 운영용 (patch, reset, add-worker)
    └── inventories/
        ├── test/
        │   ├── hosts
        │   ├── group_vars/
        └── prod/
            ├── hosts
            ├── group_vars/
```

- [TODO] Gitea Actions 연동을 통한 컨트롤 노드 배포 및 Ansible 실행 자동화

---

## 03-create-control-node.sh

- VMID 9003 클론 → 컨트롤 노드 VM(VMID 2210) 생성 및 스택 자동 설치
- 최초 한 번 실행함

### 스펙

| 항목 | 값 |
|---|---|
| VM ID | 2210 |
| 이름 | control |
| 클론 소스 | 9003 (ubuntu-2404-common-v1) |
| CPU | 2 cores / host |
| 메모리 | 2048 MB |
| 디스크 | 10G (rbd-storage) |
| 네트워크 | virtio / vmbr0 / VLAN 30 (폐쇄망) |
| 게이트웨이 | 172.16.30.1 |
| IP | 172.16.30.7/24 |
| 계정 | control |

### 주요 스택
cloud-init이 첫 부팅 시 자동 설치함. `control` 계정만 실행 가능함

| 소프트웨어 | 용도 |
|---|---|
| Terraform | Proxmox VM 프로비저닝 |
| Ansible | VM 구성 자동화 |
| etcd | 분산 키-값 저장소 |

### 사전 조건
- VMID 9003 (ubuntu-2404-common-v1) 템플릿 존재

### 변수 파일
`.env.example` 복사 후 `CIPASSWORD` 수정
```bash
cp .env.example .env
```

### SSH 공개키 등록
사용자 공개키를 `workspace/keys/` 에 추가 후 스크립트 실행 시 자동 주입
```bash
echo "ssh-ed25519 AAAA... user@laptop" > workspace/keys/name.pub
```

### 실행
```bash
bash 03-create-control-node.sh
```

### 동작 순서
1. 기존 VMID 2210 존재 시 자동 제거 (Ceph RBD 잔여 이미지 포함)
2. cicustom 스니펫 생성
3. VMID 9003 풀 클론 (1~3분 소요)
4. CPU / 메모리 / 네트워크 / RNG 설정
5. cloud-init: 고정 IP / 계정 / SSH 키 / cicustom 주입
6. VM 시작 → cloud-init 실행
   - Terraform, Ansible, etcd 자동 설치
   - SSH 비밀번호 인증 활성화
   - `control` 계정 전용 실행 권한 설정
7. 설치 완료 (총 5~10분 소요)

### 로그 확인
```bash
# VM 생성 로그 (Proxmox 호스트)
tail -f /var/log/create-control-node.log

# 스택 설치 로그 (컨트롤 노드 접속 후)
cloud-init status
cat /var/log/cloud-init-done.marker
```

### 완료 확인
```bash
ssh control@172.16.30.7
terraform version
ansible --version
etcd --version
```

---

## 03-deploy-to-control.sh

- 로컬의 Terraform + Ansible 설정을 컨트롤 노드 `~/workspace/`에 한 번에 배포
- 수정 사항 발생 시 수시로 실행하여 동기화

### 사전 조건
- `03-create-control-node.sh` 실행 완료 (컨트롤 노드 생성 및 접속 가능 상태)
- 로컬 `02.terraform` 및 `03.ansible/workspace` 내부 설정 완료

### 실행
- 배포 시 컨트롤 노드의 `~/workspace/` 전체를 삭제 후 재생성함
- `credentials.auto.tfvars` 등 컨트롤 노드에서 생성한 파일은 백업 필요

```bash
# SSH 연결 시 비밀번호 1회 입력 필요
bash 03.ansible/03-deploy-to-control.sh
```

### 동작 순서

1. 기존 컨트롤 노드의 디렉토리 초기화
2. `02.terraform/*` → 컨트롤 노드 `~/workspace/terraform/` 복사
3. `03.ansible/workspace/*` → 컨트롤 노드 `~/workspace/ansible/` 복사
4. 쉘 스크립트 실행 권한 부여

### 구조

```bash
~/workspace/
├── terraform/   # 02.terraform/*
└── ansible/     # 03.ansible/workspace/*
```

---

## 인프라 구축 실행

> 전체 예시는 [EXAMPLES.md](./EXAMPLES.md) 참조

### 0. 컨트롤 노드에 파일 배포
```bash
# 로컬에서 실행
bash 03.ansible/03-deploy-to-control.sh
```

### 1. Terraform으로 VM 생성
```bash
# DNS 전용 생성
bash ~/workspace/terraform/02-run.sh prod apply dns

# 전체 VM 생성
bash ~/workspace/terraform/02-run.sh prod apply all

# 전체 VM 제거
bash ~/workspace/terraform/02-run.sh prod destroy all

# destroy 실패 시 Proxmox 호스트에서 수동 제거 필요

# 캐싱 제거
rm -rf .terraform/ .terraform.lock.hcl
```

### 2. Ansible 플레이북 실행

- Terraform 배포 시 `credentials.auto.tfvars`의 `ssh_public_key`가 VM cloud-init으로 `kosa` 계정에 주입
- 컨트롤 노드에 대응하는 개인키(`~/.ssh/ansible`) 배치

```bash
# DNS 구성
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts ~/workspace/ansible/playbooks/dns.yml

# 전체 구성
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts ~/workspace/ansible/playbooks/site.yml

# 캐싱 제거
rm -rf ~/.ansible/cp/*
```

---


## 인프라 구성 명세

### 수동 구성

| 호스트 | VM ID | VM name | IP | DNS | 주요 스택 |
|---|---|---|---|---|---|
| kosa21 | 2002 | pfSense  | 172.16.20.5  | firewall.edge.local | 방화벽, NAT, WireGuard VPN |
| kosa21 | 2210 | Control  | 172.16.30.7  | ctrl.mgmt.local | Terraform, Ansible, etcd |
| kosa24 | 2475 | Test/Sec | 172.16.30.75 | stress.mgmt.local | Kali Linux (k6, Locust 등) |


### 자동 구성 명세 (prod)

| 호스트 | VM ID | VM name | IP | DNS 알리아스 | 주요 스택 | 스토리지 |
|---|---|---|---|---|---|---|
| - | - | DNS VIP | 172.16.30.10 | dns.svc.local    | Keepalived Float IP | - |
| kosa22 | 2211 | dns-01      | 172.16.30.11 | dns-01.svc.local | Keepalived, CoreDNS, etcd | rbd-storage |
| kosa23 | 2312 | dns-02      | 172.16.30.12 | dns-02.svc.local | Keepalived, CoreDNS, etcd | rbd-storage |
| kosa24 | 2415 | nexus-01    | 172.16.30.15 | nexus.mgmt.local | Nexus (apt mirror, binary, docker registry) | rbd-storage |
| - | - | vault-vip   | 172.16.30.20 | vault.sec.local | Keepalived Float IP | - |
| kosa21 | 2121 | vault-01    | 172.16.30.21 | vault-01.sec.local | HashiCorp Vault/PKI, Raft | rbd-storage |
| kosa24 | 2422 | vault-02    | 172.16.30.22 | vault-02.sec.local | HashiCorp Vault/PKI, Raft | rbd-storage |
| - | - | haproxy-vip | 172.16.20.25 | haproxy.svc.local | Keepalived | - |
| kosa22 | 2226 | haproxy-01  | 172.16.20.26 | haproxy-01.svc.local | Keepalived, HAProxy | rbd-storage |
| kosa23 | 2327 | haproxy-02  | 172.16.20.27 | haproxy-02.svc.local | Keepalived, HAProxy | rbd-storage |
| - | - | k8s-vip     | 172.16.30.30 | - | - | - |
| kosa21 | 2131 | k8s-master-01   | 172.16.30.31 | master-01.k8s.local | Keepalived, kubeadm | **local-lvm** |
| kosa22 | 2232 | k8s-master-02   | 172.16.30.32 | master-02.k8s.local | Keepalived, kubeadm | **local-lvm** |
| kosa23 | 2333 | k8s-master-03   | 172.16.30.33 | master-03.k8s.local | Keepalived, kubeadm | **local-lvm** |
| kosa24 | 2440 | k8s-worker-plat | 172.16.30.40 | node-plat.k8s.local | Ingress, ArgoCD | rbd-storage |
| kosa21 | 2145 | k8s-worker-01   | 172.16.30.45 | node-01.k8s.local | kubelet | rbd-storage |
| kosa22 | 2246 | k8s-worker-02   | 172.16.30.46 | node-02.k8s.local | kubelet | rbd-storage |
| kosa23 | 2347 | k8s-worker-03   | 172.16.30.47 | node-03.k8s.local | kubelet | rbd-storage |
| kosa24 | 2455 | cicd-01         | 172.16.30.55 | gitea.mgmt.local | Gitea | rbd-storage |
| - | - | DB VIP          | 172.16.30.60 | db-cluster.svc.local | Percona XtraDB Cluster | - |
| kosa23 | 2361 | proxysql-01     | 172.16.30.61 | sql-01.svc.local | ProxySQL | rbd-storage |
| kosa24 | 2462 | proxysql-02     | 172.16.30.62 | sql-02.svc.local | ProxySQL | rbd-storage |
| kosa21 | 2165 | percona-01      | 172.16.30.65 | percona-01.svc.local | Percona XtraDB Cluster (PXC) | rbd-storage |
| kosa22 | 2266 | percona-02      | 172.16.30.66 | percona-02.svc.local | Percona XtraDB Cluster (PXC) | rbd-storage |
| kosa23 | 2367 | percona-03      | 172.16.30.67 | percona-03.svc.local | Percona XtraDB Cluster (PXC) | rbd-storage |
| kosa24 | 2470 | minio-01        | 172.16.30.70 | minio.mgmt.local | MinIO (Terraform Backend) | rbd-storage |
| kosa22 | 2290 | siem-01         | 172.16.30.90 | siem.mgmt.local | Wazuh | rbd-storage |
| kosa23 | 2395 | monitor-01      | 172.16.30.95 | monitor.mgmt.local | PLG Stack | rbd-storage |

**VIP 리스트**
| 서비스 | VIP | DNS 알리아스 | 비고 |
|---|---|---|---|
| DNS VIP | 172.16.30.10 | dns.svc.local | CoreDNS HA |
| Vault VIP | 172.16.30.20 | vault.sec.local | HashiCorp Vault HA |
| HAProxy VIP | 172.16.20.25 | haproxy.svc.local | 외부 접점 |
| K8s VIP | 172.16.30.30 | - | API Server HA |
| DB VIP | 172.16.30.60 | db-cluster.svc.local | Percona XtraDB Cluster |

### 자동 구성 명세 (test)

| 호스트 | VM ID | VM name | IP | DNS 알리아스 | 주요 스택 | 스토리지 |
|---|---|---|---|---|---|---|
| kosa21 | 21200 | test-k8s-master-01 | 172.16.30.200 | test-master-01.k8s.local | test 마스터 노드 | **local-lvm** |
| kosa23 | 23201 | test-k8s-master-02 | 172.16.30.201 | test-master-02.k8s.local | test 마스터 노드 | **local-lvm** |
| kosa22 | 22205 | test-k8s-platform-01 | 172.16.30.205 | test-node-plat.k8s.local | test 플랫폼 워커 | rbd-storage |
| kosa22 | 22207 | test-k8s-worker-01 | 172.16.30.207 | test-node-01.k8s.local | test 워커 노드 | rbd-storage |
| kosa24 | 24209 | test-k8s-worker-02 | 172.16.30.209 | test-node-02.k8s.local | test 워커 노드 | rbd-storage |
| kosa21 | 21210 | test-dns-01 | 172.16.30.210 | test-dns-01.svc.local | test DNS 서버 | rbd-storage |
| kosa23 | 23211 | test-dns-02 | 172.16.30.211 | test-dns-02.svc.local | test DNS 서버 | rbd-storage |
| kosa24 | 24215 | test-vault-01 | 172.16.30.215 | test-vault-01.sec.local | test 보안 서버 | rbd-storage |

