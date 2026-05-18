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
├── 02-run.sh                         # Terraform 실행 랩퍼 스크립트
├── 02-force-destroy-all.sh           # VM 강제 삭제 스크립트 (장애 복구용)
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

- [TODO] `ssh_public_key` 변수를 Vault에서 가져오도록 수정함
- [TODO] Vault 구성 완료 후 credentials.auto.tfvars → vault provider로 대체함

---

## 02-run.sh

- 컨트롤 노드(`~/workspace/terraform/`)에서 사용하는 실행 랩퍼 스크립트
- 환경(`test/prod`) 및 대상 롤(`tfvars`)을 인자로 받아 명령어 자동 구성함
- 다중 클론 시 Ceph RBD 락 방지를 위해 `-parallelism=1` 주입 (안정화 후 3~5로 상향 예정)

> 전체 예시(테라폼 + 앤서블)는 [EXAMPLES.md](./EXAMPLES.md) 참조

```bash
# DNS 전용 생성
bash ~/workspace/terraform/02-run.sh prod apply dns

# 전체 VM 생성
bash ~/workspace/terraform/02-run.sh prod apply all

# 전체 VM 제거
bash ~/workspace/terraform/02-run.sh prod destroy all

# 캐싱 제거 (상태 꼬임 발생 시)
rm -rf ~/workspace/terraform/env/prod/.terraform/
```

**제거 실패 시**
- Ceph RBD 락 충돌 또는 설정 파일 잔류로 destroy 실패 가능
- `02-force-destroy-all.sh`로 강제 제거


## 02-force-destroy-all.sh

- 컨트롤 노드에서 실행하는 Proxmox VM 강제 정리 스크립트
- Terraform `destroy` 실패 시 잔여 VM이나 RBD 디스크 락 등 상태가 꼬였을 때 강제 복구함

**사전 조건: SSH 키 등록 (컨트롤 노드)**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_proxmox -N ""
ssh-copy-id -i ~/.ssh/id_proxmox.pub root@192.168.34.2
ssh-copy-id -i ~/.ssh/id_proxmox.pub root@192.168.34.3
ssh-copy-id -i ~/.ssh/id_proxmox.pub root@192.168.34.4
ssh-copy-id -i ~/.ssh/id_proxmox.pub root@192.168.34.5
```

**사용법**
```bash
# VMID 지정 필수 (생략 시 스크립트 오류로 중단)
bash ~/workspace/terraform/02-force-destroy-all.sh kosa21 2131  # k8s-master-01
bash ~/workspace/terraform/02-force-destroy-all.sh kosa22 2232  # k8s-master-02
bash ~/workspace/terraform/02-force-destroy-all.sh kosa23 2333  # k8s-master-03
bash ~/workspace/terraform/02-force-destroy-all.sh kosa24 2440  # k8s-worker-plat
bash ~/workspace/terraform/02-force-destroy-all.sh kosa21 2145  # k8s-worker-01
bash ~/workspace/terraform/02-force-destroy-all.sh kosa22 2246  # k8s-worker-02
bash ~/workspace/terraform/02-force-destroy-all.sh kosa23 2347  # k8s-worker-03
```

**내부 동작**
1. `qm stop --skiplock` — 실행 중인 VM 강제 중지
2. `qm set --delete scsi0/scsi1/...` — VM config에서 디스크 참조 제거
3. `qm destroy --purge --destroy-unreferenced-disks` — VM 삭제 시도
4. `rm -f /etc/pve/nodes/*/qemu-server/<VMID>.conf` — 설정 파일 강제 삭제 (ghost VM 제거)
5. `lvremove -f pve/<LV>` — 로컬 LV 잔여물 제거 (cloudinit 등)
6. `rbd rm <pool>/<vol>` — Ceph pool에서 orphaned RBD 볼륨 직접 제거


**제거 순서**
> Terraform destroy 없이 force destroy만 실행하면 Proxmox VM은 삭제되지만 state에 VM이 잔류해 이후 apply 시 충돌 발생

1. Terraform으로 먼저 제거 (state + Proxmox 동시 정리)
```bash
bash ~/workspace/terraform/02-run.sh prod destroy k8s-master
bash ~/workspace/terraform/02-run.sh prod destroy k8s-worker
```
2. Proxmox에 VM이 잔류하면 force destroy 스크립트로 수동 정리

**정상 제거 vs 강제 제거**

| 상황 | 방법 |
|---|---|
| Terraform state에 존재 | `02-run.sh prod destroy <ROLE>` |
| state에 없으나 Proxmox에 잔류 (ghost VM) | `02-force-destroy-all.sh <NODE> <VMID>` |


---

## VM 구성

### 스펙 기본값

| 항목 | 기본값 | 비고 |
|---|---|---|
| CPU | 2 cores | tfvars에서 VM별 개별 지정 가능 |
| 메모리 | 2048 MB | tfvars에서 VM별 개별 지정 가능 |
| 디스크 | 10 GB | tfvars에서 VM별 개별 지정 가능 |

## 10G 스토리지 네트워크 (vmbr1)

- Ceph 트래픽을 서비스망(172.16.x.x)과 분리하기 위한 전용 브리지
- Proxmox 호스트 브리지: `vmbr1` (10.10.10.0/24, MTU 9000)
- VM 옵션(선택): `storage_ip`, `storage_bridge`(기본 `vmbr1`), `storage_cidr`(기본 `24`), `storage_mtu`(기본 `9000`)

```hcl
"k8s-worker-01" = {
  ...
  storage_ip     = "10.10.10.211"
  storage_bridge = "vmbr1"
  storage_cidr   = 24
  node           = "kosa21"
}
```

k8s 노드 스토리지 IP 할당 범위
- prod: `10.10.10.200~213`
- test: `10.10.10.230~243`

### VM 목록

> 전체 VM 구성은 [Ansible 인프라 명세](../03.ansible/README.md#인프라-구성-명세) 참조

---

## 실행

### 사전 조건

- VMID 9003, 9005 템플릿 존재함
- Proxmox API 토큰 발급 완료함
- `credentials.auto.tfvars` 작성 완료함 (`credentials.auto.tfvars.example` 참조)
- 컨트롤 노드(2210, 172.16.30.7)에서 실행함
- [TODO] Vault 구성 완료 후 credentials.auto.tfvars → vault provider로 대체함

### 파일 동기화

```bash
# 로컬에서 실행
bash 03.ansible/03-deploy-to-control.sh
```

### 배포

```bash
# 역할별 배포 (컨트롤 노드에서 실행)
bash ~/workspace/terraform/02-run.sh prod apply dns
bash ~/workspace/terraform/02-run.sh prod apply k8s-master
bash ~/workspace/terraform/02-run.sh prod apply k8s-worker

# 특정 VM만 배포
bash ~/workspace/terraform/02-run.sh prod apply k8s-master k8s-master-01
```

### 동작 순서

1. `template_vm_id`에 따라 9003 또는 9005 풀 클론
2. CPU / 메모리 / 디스크 설정 적용
3. 네트워크: 브리지, VLAN 설정 (방화벽 비활성화)
4. cloud-init: DNS 서버, 고정 IP / 게이트웨이 주입
5. qemu-guest-agent 활성화 확인

---

## 트러블슈팅

```bash
# state 확인 (컨트롤 노드에서 실행)
cd ~/workspace/terraform/env/prod
terraform state list

# state lock 해제 (프로세스 비정상 종료 시)
ps aux | grep terraform
kill -9 <PID>

# 특정 VM만 재생성
bash ~/workspace/terraform/02-run.sh prod apply k8s-master k8s-master-01
```