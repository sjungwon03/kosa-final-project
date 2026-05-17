# Terraform

- VMID 9003 (ubuntu-2404-common) 템플릿을 클론하여 Proxmox에 VM 프로비저닝
- Ceph(rbd-storage) 공유 스토리지 사용

**파이프라인 (실행 순서)**

| 순서 | 폴더 | 내용 | 실행 위치 |
|---|---|---|---|
| 1 | 00.scripts | 베이스 템플릿(9000) 생성 | Proxmox 호스트 |
| 2 | 01.packer | 공통 템플릿(9003) 생성 | 빌드 서버 |
| 3 | 03.ansible | 컨트롤 노드 VM 생성 | Proxmox 호스트 |
| 4 | **02.terraform** | **VM 프로비저닝** | **컨트롤 노드** |
| 5 | 03.ansible | Ansible 플레이북 실행 | 컨트롤 노드 |

**디렉토리 구성**
```
02.terraform/
├── main.tf                          # VM 리소스 (모듈)
├── variables.tf                     # 모듈 입력 변수
├── outputs.tf                       # VM 이름, ID, IP 출력
└── env/
    ├── test/                        # 테스트 환경
    │   ├── main.tf                  # provider + module 호출
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── credentials.auto.tfvars  # API 인증 정보 (gitignore)
    │   ├── credentials.auto.tfvars.example
    │   └── tfvars/                  # 역할별 VM 목록
    │       ├── all.tfvars
    │       ├── dns.tfvars
    │       ├── haproxy.tfvars
    │       ├── vault.tfvars
    │       ├── k8s-master.tfvars
    │       ├── k8s-worker.tfvars
    │       └── services.tfvars
    └── prod/                        # 프로덕션 환경
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── credentials.auto.tfvars  # API 인증 정보 (gitignore)
        ├── credentials.auto.tfvars.example
        └── tfvars/
            ├── all.tfvars
            ├── dns.tfvars
            ├── haproxy.tfvars
            ├── vault.tfvars
            ├── k8s-master.tfvars
            ├── k8s-worker.tfvars
            └── services.tfvars
```

---

## VM 구성

## 10G 스토리지 네트워크 (vmbr1)

- 목적: Ceph 트래픽을 서비스망(172.16.x.x)과 분리
- Proxmox 호스트 브리지: `vmbr1` (10.10.10.0/24, MTU 9000)
- Terraform VM 옵션(선택):
  - `storage_ip`
  - `storage_bridge` (기본 `vmbr1`)
  - `storage_cidr` (기본 `24`)
  - `storage_mtu` (기본 `9000`)

예시:
```hcl
"k8s-worker-01" = {
  vm_id          = 2145
  ip             = "172.16.30.45"
  vlan           = 30
  bridge         = "vmbr0"
  storage_ip     = "10.10.10.211"
  storage_bridge = "vmbr1"
  storage_cidr   = 24
  node           = "kosa21"
}
```

현재 k8s 노드 할당 범위:
- prod: `10.10.10.200~213`
- test: `10.10.10.230~243`

### 스펙 기본값

| 항목 | 기본값 | 비고 |
|---|---|---|
| CPU | 2 cores | tfvars에서 VM별 개별 지정 가능 |
| 메모리 | 2048 MB | tfvars에서 VM별 개별 지정 가능 |
| 디스크 | 10 GB | tfvars에서 VM별 개별 지정 가능 |

### VM 목록

| 이름 | VMID | IP | VLAN | 노드 | 주요 스택 |
|---|---|---|---|---|---|
| dns1 | 2211 | 172.16.30.11 | 30 | kosa22 | CoreDNS, etcd, Keepalived |
| dns2 | 2312 | 172.16.30.12 | 30 | kosa23 | CoreDNS, etcd, Keepalived |
| vault1 | 2115 | 172.16.30.20 | 30 | kosa21 | HashiCorp Vault |
| vault2 | 2416 | 172.16.30.21 | 30 | kosa24 | HashiCorp Vault |
| haproxy1 | 2226 | 172.16.20.26 | 20 | kosa22 | HAProxy, Keepalived |
| haproxy2 | 2327 | 172.16.20.27 | 20 | kosa23 | HAProxy, Keepalived |
| k8s-master-01 | 2130 | 172.16.30.30 | 30 | kosa21 | kubeadm, kube-apiserver |
| k8s-master-02 | 2231 | 172.16.30.31 | 30 | kosa22 | kubeadm, kube-apiserver |
| k8s-master-03 | 2332 | 172.16.30.32 | 30 | kosa23 | kubeadm, kube-apiserver |
| k8s-worker-plat | 2440 | 172.16.30.40 | 30 | kosa24 | Ingress, MetalLB, ArgoCD, Falco |
| k8s-worker-01 | 2141 | 172.16.30.41 | 30 | kosa21 | kubelet |
| k8s-worker-02 | 2242 | 172.16.30.42 | 30 | kosa22 | kubelet |
| k8s-worker-03 | 2343 | 172.16.30.43 | 30 | kosa23 | kubelet |
| registry | 2150 | 172.16.30.50 | 30 | kosa21 | Harbor |
| cicd | 2455 | 172.16.30.55 | 30 | kosa24 | Gitea |
| siem | 2270 | 172.16.30.70 | 30 | kosa22 | Wazuh |
| monitoring | 2380 | 172.16.30.80 | 30 | kosa23 | Grafana, Prometheus, Loki |

> DNS VIP: 172.16.30.10 / HAProxy VIP: 172.16.20.25 (Keepalived Float IP)

- [TODO] CoreDNS 구성 완료 후 `vm_nameserver`를 DNS VIP(172.16.30.10)로 변경
- [TODO] `ssh_public_key` 변수를 Vault에서 가져오도록 수정
- [TODO] MinIO 가상 서버 구축 후 Terraform Backend 구성



## 실행

### 사전 조건

- VMID 9003, 9005 템플릿 존재
- Proxmox API 토큰 발급
- 컨트롤 노드(2210, 172.16.30.7)에서 실행

### 변수 파일 설정

**Proxmox API 인증 정보**
- `env/{test,prod}` 디렉토리에서 `credentials.auto.tfvars.example` 복사 후 Token Secret 입력

```bash
# env/test 또는 env/prod 디렉토리에서 실행
cp credentials.auto.tfvars.example credentials.auto.tfvars
```

### 파일 전송

```bash
# 로컬에서 실행
ssh control@172.16.30.7 "rm -rf ~/terraform"
scp -r 02.terraform control@172.16.30.7:~/terraform
```

### 변수 파일

```bash
# TOKEN_SECRET 입력 후 저장
cp credentials.auto.tfvars.example credentials.auto.tfvars
```

```hcl
proxmox_api_url          = "https://192.168.34.4:8006/api2/json"
proxmox_api_token_id     = "terraform-prov@pve!terraform-token"
proxmox_api_token_secret = "<TOKEN_SECRET>"
```

> [TODO] Vault 구성 완료 후 credentials.auto.tfvars → vault provider로 대체

### 배포

```bash
cd ~/terraform

# 실행 권한 부여 (최초 1회)
chmod +x 02-run.sh

# terraform init은 스크립트 내부에서 자동 실행됨 (최초 실행 시 프로바이더 다운로드)

# [방법 1] 역할별(파일별)로 VM 그룹 배포
# dns.tfvars에 정의된 VM들만 생성
./02-run.sh prod apply dns

# k8s-master.tfvars에 정의된 VM들만 생성
./02-run.sh prod apply k8s-master

# [방법 2] 전체 배포
# all.tfvars를 사용하여 모든 VM을 한 번에 배포
./02-run.sh prod apply all

# [방법 3] 특정 VM만 골라서 배포 (기존 state 유지)
# all.tfvars를 기준으로 하되, 그중 "dns1" VM만 생성 또는 변경
./02-run.sh prod apply all dns1
```

### 동작 순서

1. VMID 9003 풀 클론 → 노드별 VM 생성
2. CPU / 메모리 / 디스크 설정 적용
3. 네트워크: 브리지, VLAN 설정 (방화벽 비활성화)
4. cloud-init: DNS 서버, 고정 IP / 게이트웨이 주입
5. qemu-guest-agent 활성화 확인

---

## 트러블슈팅

```bash
# 상태 확인
terraform state list
terraform show

# apply 실패 후 재시도 (생성된 VM은 건너뜀)
terraform apply -var-file=tfvars/all.tfvars -parallelism=1

# state lock 해제 (프로세스 비정상 종료 시)
ps aux | grep terraform
kill <PID>
rm .terraform.tfstate.lock.info

# VM 삭제
terraform destroy -var-file=tfvars/all.tfvars -parallelism=1

# 특정 VM만 재생성
terraform apply -replace='module.vms.proxmox_virtual_environment_vm.ubuntu["dns1"]' -parallelism=1
```

---

## K8s 워커 추가

- 워커 IP는 40번대, VMID는 `[노드번호][IP끝자리]` 규칙
- `k8s-worker.tfvars`에 미리 정의되어 필요 시 `-target`으로 개별 생성

| 이름 | VMID | IP | 노드 |
|---|---|---|---|
| k8s-worker-04 | 2144 | 172.16.30.44 | kosa21 |
| k8s-worker-05 | 2245 | 172.16.30.45 | kosa22 |
| k8s-worker-06 | 2346 | 172.16.30.46 | kosa23 |


```bash
# 개별 생성
terraform apply -var-file=tfvars/k8s-worker.tfvars -target='module.vms.proxmox_virtual_environment_vm.ubuntu["k8s-worker-04"]' -parallelism=1

# 생성 후 Ansible로 클러스터 join
ansible-playbook -i inventories/prod/hosts playbooks/k8s.yml --limit k8s-worker-04
```

> [TODO] 노드 자동 프로비저닝: Gitea Actions runner를 컨트롤 노드에 등록 후 `k8s-worker.tfvars` push 시 자동 실행
