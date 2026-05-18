# Terraform

- VMID 9003(ubuntu-2404-common), 9005(ubuntu-2404-k8s) 템플릿을 클론하여 Proxmox에 VM 프로비저닝
- 기본은 9003 지정, K8s 노드(`k8s-master-*`, `k8s-worker-*`)는 `template_vm_id = 9005` 지정

**파이프라인 (실행 순서)**

| 순서 | 폴더 | 내용 | 실행 위치 |
|---|---|---|---|
| 1 | 00.scripts | 베이스 템플릿(9000) 생성 | Proxmox 호스트 |
| 2 | 01.packer | 공통 템플릿(9003, 9005) 생성 | 빌드 서버 |
| 3 | 03.ansible | 컨트롤 노드 VM 생성 | Proxmox 호스트 |
| 4 | **02.terraform** | **VM 프로비저닝** | **컨트롤 노드** |
| 5 | 03.ansible | Ansible 플레이북 실행 | 컨트롤 노드 |

**디렉토리 구성**

```
02.terraform/
├── 02-force-destroy-all.sh           # VM 강제 삭제 스크립트 (장애 복구용)
├── 02-run.sh                         # Terraform 실행 랩퍼 스크립트
├── main.tf                           # VM 리소스 (모듈)
├── variables.tf                      # 모듈 입력 변수
├── outputs.tf                        # VM 이름, ID, IP 출력
└── env/
    ├── test/                         # 테스트 환경
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
    └── prod/                         # 프로덕션 환경
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── credentials.auto.tfvars   # API 인증 정보 (gitignore)
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

- [TODO] CoreDNS 구성 완료 후 `vm_nameserver`를 DNS VIP(172.16.30.10)로 변경함
- [TODO] `ssh_public_key` 변수를 Vault에서 가져오도록 수정함
- [TODO] MinIO 가상 서버 구축 후 Terraform Backend 구성함

---

## 02-force-destroy-all.sh

- 로컬(작업자 PC)에서 실행하는 Proxmox VM 강제 정리 스크립트
- Terraform `destroy` 실패 시 잔여 VM이나 RBD 디스크 락 등 상태가 꼬였을 때 강제 복구함
- SSH를 통해 대상 노드에 접속 후 `qm stop` 및 `qm destroy` 직접 호출함
- 사용법: `bash 02-force-destroy-all.sh [TARGET_NODE]` (예: `all`, `kosa21`)

## 02-run.sh

- 컨트롤 노드(`~/workspace/terraform/`)에서 사용하는 실행 랩퍼(Wrapper) 스크립트
- 환경(`test/prod`) 및 대상 롤(`tfvars`)을 인자로 받아 명령어 자동 구성함
- 다중 클론 시 스토리지 락 방지를 위해 `-parallelism=1` 자동 주입함
- 사용법: `./02-run.sh <ENV> <ACTION> <ROLE> [TARGET_VM]`
  - 예시: `./02-run.sh prod apply k8s-master`


```bash
# DNS 전용 생성
bash ~/workspace/terraform/02-run.sh prod apply dns

# 전체 VM 생성
bash ~/workspace/terraform/02-run.sh prod apply all

# 전체 VM 제거
bash ~/workspace/terraform/02-run.sh prod destroy all

# destroy 실패 시 Proxmox 호스트에서 수동 제거 필요
- Ceph RBD 락 충돌
- 설정 파일 잔류
```


---

## VM 구성

### 스펙 기본값

| 항목 | 기본값 | 비고 |
|---|---|---|
| CPU | 2 cores | tfvars에서 VM별 개별 지정 가능 |
| 메모리 | 2048 MB | tfvars에서 VM별 개별 지정 가능 |
| 디스크 | 10 GB | tfvars에서 VM별 개별 지정 가능 |

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

### VM 목록

> 전체 VM 구성은 [Ansible 인프라 명세](../03.ansible/README.md#인프라-구성-명세) 참조

## 실행

### 사전 조건

- VMID 9003, 9005 템플릿 존재함
- Proxmox API 토큰 발급 완료함
- 컨트롤 노드(2210, 172.16.30.7)에서 실행함

### 변수 파일 설정

**Proxmox API 인증 정보**
- `env/{test,prod}` 디렉토리에서 `credentials.auto.tfvars.example` 복사 후 Token Secret 입력함

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

> [TODO] Vault 구성 완료 후 credentials.auto.tfvars → vault provider로 대체함

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
# all.tfvars를 기준으로 하되 그중 "dns1" VM만 생성 또는 변경
./02-run.sh prod apply all dns1
```

### 동작 순서

1. `template_vm_id`에 따라 9003 또는 9005 풀 클론 → 노드별 VM 생성함
2. CPU / 메모리 / 디스크 설정 적용함
3. 네트워크: 브리지, VLAN 설정 (방화벽 비활성화)
4. cloud-init: DNS 서버, 고정 IP / 게이트웨이 주입함
5. qemu-guest-agent 활성화 확인 및 설치함

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