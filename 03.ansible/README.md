# Ansible

컨트롤 노드 VM 생성 및 Ansible 플레이북 관리

**사용 목적**
- 초기 구축: 소프트웨어 설치, 클러스터 초기화
- 운영 자동화: 설정 변경, 노드 추가, 패치, 복구

> 초기 구축(`playbooks/`)과 운영(`playbooks/ops/`)으로 구분

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
    │   ├── dns/                # CoreDNS + etcd + Keepalived
    │   ├── haproxy/            # HAProxy + Keepalived
    │   ├── registry/           # 컨테이너 레지스트리
    │   ├── k8s_common/         # k8s 공통 설정
    │   ├── k8s_master/         # k8s 마스터 노드
    │   ├── k8s_worker/         # k8s 워커 노드
    │   ├── monitor/            # 모니터링 (Grafana, Loki 등)
    │   └── ...                 # CICD, SIEM, Vault 추가 예정
    ├── playbooks/
    │   ├── site.yml            # 전체 실행
    │   ├── dns.yml
    │   ├── haproxy.yml
    │   ├── registry.yml
    │   ├── k8s.yml
    │   └── monitor.yml
    └── inventories/
        ├── test/
        │   ├── hosts
        │   ├── group_vars/     # test 전용 오버라이드
        │   └── certs/          # gitignore 대상
        └── prod/
            ├── hosts
            ├── group_vars/     # prod 전용 오버라이드
            └── certs/          # gitignore 대상
```

- [TODO] Gitea Actions 연동을 통한 컨트롤 노드 배포 및 Ansible 실행 자동화

---

## 03-create-control-node.sh

- VMID 9003 클론 → 컨트롤 노드 VM(VMID 2210) 생성 및 스택 자동 설치
- 최초 한 번 실행

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
| IP | 172.16.30.7/24 |
| 게이트웨이 | 172.16.30.1 |
| 계정 | control |

### 주요 스택

cloud-init이 첫 부팅 시 자동 설치. `control` 계정만 실행 가능

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

사용자 공개키를 `workspace/keys/` 에 추가 후 sh 실행 시 자동 주입

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

- 로컬에서 Terraform + Ansible 파일을 컨트롤 노드 `~/workspace/`에 한 번에 배포
- 반복 실행 가능 (수정 사항 동기화)

### 사전 조건

- `03-create-control-node.sh` 실행 완료 (컨트롤 노드 생성 및 접속 가능 상태)
- 로컬 `02.terraform` 및 `03.ansible/workspace` 내부 설정 완료

### 실행

- 배포 시 컨트롤 노드의 `~/workspace/` 전체를 삭제 후 재생성함
- `credentials.auto.tfvars` 등 컨트롤 노드에서 생성한 파일은 미리 백업 필요

```bash
# 프로젝트 루트에서 실행, 최초 SSH 연결 시 비밀번호 1회 입력
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
├── terraform/   # 02.terraform/* 전체
└── ansible/     # 03.ansible/workspace/* 전체
```

---

## 인프라 구축 실행

> 전체 예시는 [EXAMPLES.md](./EXAMPLES.md) 참조

### 1단계: Terraform으로 VM 생성

```bash
cd ~/workspace/terraform/env/test
cp credentials.auto.tfvars.example credentials.auto.tfvars
# credentials.auto.tfvars 편집 (API 토큰, ssh_public_key 입력) 후

# 전체 실행 (Ceph clone 충돌 방지를 위해 parallelism=1 필수)
../../02-run.sh test apply all

# 역할별 배포
../../02-run.sh test apply dns
../../02-run.sh test apply k8s-master

# VM 삭제
../../02-run.sh test destroy all
```

### 2단계: Ansible SSH 접근 설정

- Terraform 배포 시 `credentials.auto.tfvars`의 `ssh_public_key`가 VM cloud-init으로 `kosa` 계정에 주입
- 컨트롤 노드에 대응하는 개인키(`~/.ssh/ansible`) 배치

```bash
# 확인
ls ~/.ssh/ansible

# 없을 경우 새로 생성 후 공개키를 `credentials.auto.tfvars`의 `ssh_public_key`에 반영
ssh-keygen -t ed25519 -f ~/.ssh/ansible -C "ansible@control" -N ""
cat ~/.ssh/ansible.pub  # credentials.auto.tfvars의 ssh_public_key에 추가

# 접속 확인
cd ~/workspace/ansible
ansible all -m ping
```

### 3단계: Ansible 플레이북 실행

```bash
cd ~/workspace/ansible

# prod
ansible-playbook playbooks/dns.yml
ansible-playbook playbooks/site.yml

# test
ansible-playbook -i inventories/test/hosts playbooks/site.yml
```

---

## 인프라 구성 명세 (prod)

### 수동 구성

| 호스트 | VM ID | VM name | IP | DNS | 주요 스택 |
|---|---|---|---|---|---|
| kosa21 | 2002 | pfSense  | 172.16.20.5  | firewall.edge.local | 방화벽 (Proxmox VM 방화벽은 비활성화) |
| kosa21 | 2210 | Control  | 172.16.30.7  | ctrl.mgmt.local | Terraform, Ansible, etcd |
| kosa24 | 2475 | Test/Sec | 172.16.30.75 | stress.mgmt.local | Kali Linux (k6, Locust) |


### 자동 구성 (Terraform + Ansible)

| 호스트 | VM ID | VM name | IP | DNS | 주요 스택 |
|---|---|---|---|---|---|
| - | - | DNS VIP | 172.16.30.10 | dns.svc.local | Keepalived Float IP |
| kosa22 | 2211 | DNS #1 | 172.16.30.11 | dns-01.svc.local | Keepalived, CoreDNS, etcd |
| kosa23 | 2312 | DNS #2 | 172.16.30.12 | dns-02.svc.local | Keepalived, CoreDNS, etcd |
| kosa21 | 2115 | Vault #1 | 172.16.30.20 | vault-01.sec.local | HashiCorp Vault, Vault PKI |
| kosa24 | 2416 | Vault #2 | 172.16.30.21 | vault-02.sec.local | HashiCorp Vault, Vault PKI |
| - | - | HAProxy VIP | 172.16.20.25 | haproxy.svc.local | Keepalived |
| kosa22 | 2226 | HAProxy #1 | 172.16.20.26 | haproxy-01.svc.local | Keepalived, HAProxy |
| kosa23 | 2327 | HAProxy #2 | 172.16.20.27 | haproxy-02.svc.local | Keepalived, HAProxy |
| - | - | K8s VIP | 172.16.30.30 | - | Keepalived |
| kosa21 | 2131 | K8s Master #01 | 172.16.30.31 | master-01.k8s.local | Keepalived, kubeadm |
| kosa22 | 2232 | K8s Master #02 | 172.16.30.32 | master-02.k8s.local | Keepalived, kubeadm |
| kosa23 | 2333 | K8s Master #03 | 172.16.30.33 | master-03.k8s.local | Keepalived, kubeadm |
| kosa24 | 2440 | Platform Worker | 172.16.30.40 | node-plat.k8s.local | Ingress, MetalLB, ArgoCD, Falco |
| kosa21 | 2145 | K8s Worker #01 | 172.16.30.45 | node-01.k8s.local | kubelet |
| kosa22 | 2246 | K8s Worker #02 | 172.16.30.46 | node-02.k8s.local | kubelet |
| kosa23 | 2347 | K8s Worker #03 | 172.16.30.47 | node-03.k8s.local | kubelet |
| kosa21 | 2150 | Registry | 172.16.30.50 | registry.mgmt.local | Harbor |
| kosa24 | 2455 | CICD | 172.16.30.55 | cicd.mgmt.local | Gitea, Act_Runner |
| kosa22 | 2270 | SIEM | 172.16.30.70 | siem.mgmt.local | Wazuh |
| kosa23 | 2380 | Monitoring | 172.16.30.80 | monitor.mgmt.local | Grafana, Prometheus, Loki |

---

## [TODO] K8s 워커 노드 풀(Pool) 사전 프로비저닝

오토스케일링 대비 및 생성 시간 단축을 위해 예비 워커 노드를 사전 생성해두고 클러스터에는 조인하지 않는 구성

- **대상 IP 대역**: `172.16.30.48~.50` (VMID: 2148, 2249, 2350)
- **동작 방식**: 기존 워커 장애 시 Gitea Actions 트리거 → `ansible playbooks/ops/add-worker.yml --limit <IP>` 실행으로 즉시 조인
- `02.terraform/env/prod/tfvars/k8s-worker-pool.tfvars`로 분리하여 관리

> **Terraform은 파일을 분리하고 Ansible은 분리하지 않음**
> - **Terraform**: 상태(State)를 관리하므로 예비 워커 풀을 메인 클러스터와 섞이지 않게 분리해 프로비저닝 해야 안전
> - **Ansible**: 행위(Task)를 수행하므로 파일 분리 불필요. 기존 `add-worker.yml`에 `--limit <IP>` 옵션을 통해 동적으로 타겟 지정
