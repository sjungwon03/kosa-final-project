# Terraform

- 9003, 9005 템플릿을 클론하여 Proxmox에 VM 프로비저닝
- 기본은 9003 템플릿, K8s 노드(`k8s-master-*`, `k8s-worker-*`)는 9005 템플릿 사용

**파이프라인**

| 순서 | 폴더 | 내용 | 실행 위치 |
|---|---|---|---|
| 1 | 00.proxmox | 베이스 템플릿(9000) 생성 | Proxmox 호스트 |
| 2 | 01.packer | 공통 템플릿(9003, 9005) 생성 | 빌드 서버 |
| 3 | 03.ansible | 컨트롤 노드 VM 생성 | Proxmox 호스트 |
| 4 | **02.terraform** | **VM 프로비저닝** | **컨트롤 노드** |
| 5 | 03.ansible | Ansible 플레이북 실행 | 컨트롤 노드 |

**디렉토리 구성**
```
02.terraform/
└── workspace/                        # 컨트롤 노드 동기화 대상
    ├── terraform-run.sh              # Terraform 실행 랩퍼 스크립트
    ├── terraform-force-destroy.sh    # VM 강제 삭제 스크립트 (장애 복구용)
    ├── main.tf                       # VM 리소스 (모듈)
    ├── variables.tf                  # 모듈 입력 변수
    ├── outputs.tf                    # VM 이름, ID, IP 출력
    └── env/
        ├── test/                     # 테스트 환경
        │   ├── main.tf               # provider + module 호출
        │   ├── variables.tf
        │   ├── outputs.tf
        │   ├── credentials.auto.tfvars   # API 인증 정보 (gitignore)
        │   ├── credentials.auto.tfvars.example
        │   └── tfvars/               # 역할별 VM 목록
        └── prod/                     # 프로덕션 환경
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            ├── credentials.auto.tfvars   # API 인증 정보 (gitignore)
            ├── credentials.auto.tfvars.example
            └── tfvars/
```

**목차**
- [VM 프로비저닝 (구축)](#vm-프로비저닝)
- [VM 구성](#vm-구성)
- [실행](#실행)
- [트러블슈팅](#트러블슈팅)

---

## VM 프로비저닝

// 설명

// > 워크스페이스가 컨트롤 노드에 넘어가야 함을 설명


**스크립트 목록**
- `terraform-run.sh`: 환경/롤 인자 기반 Terraform 실행 랩퍼
- `terraform-force-destroy.sh`: Terraform destroy 실패 시 VM 강제 정리

### terraform-run.sh

- 컨트롤 노드에서 사용하는 실행 랩퍼 스크립트
- 환경(`test/prod`) 및 대상 롤(`tfvars`)을 인자로 받아 명령어 자동 구성함
- 다중 클론 시 Ceph RBD 락 방지를 위해 `-parallelism=1` 주입 (안정화 후 3~5로 상향 예정)

```bash
# [컨트롤 노드] DNS 전용 생성
bash ~/terraform/terraform-run.sh prod apply dns

# [컨트롤 노드] 전체 VM 생성
bash ~/terraform/terraform-run.sh prod apply all

# [컨트롤 노드] 전체 VM 제거
bash ~/terraform/terraform-run.sh prod destroy all

# [컨트롤 노드] 캐싱 제거 (상태 꼬임 발생 시)
rm -rf ~/terraform/env/prod/.terraform/
```

**제거 실패 시**
- Ceph RBD 락 충돌 또는 설정 파일 잔류로 destroy 실패 가능
- `terraform-force-destroy.sh`로 강제 제거

### terraform-force-destroy.sh

- 컨트롤 노드에서 실행하는 Proxmox VM 강제 정리 스크립트
- Terraform `destroy` 실패 시 잔여 VM이나 RBD 디스크 락 등 상태가 꼬였을 때 강제 복구함

> 현재 스크립트 수정 필요 상태, 수동 명령어 사용 권장 

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
bash ~/terraform/terraform-force-destroy.sh kosa21 2131  # k8s-master-01
bash ~/terraform/terraform-force-destroy.sh kosa22 2232  # k8s-master-02
bash ~/terraform/terraform-force-destroy.sh kosa23 2333  # k8s-master-03
bash ~/terraform/terraform-force-destroy.sh kosa24 2440  # k8s-worker-plat
bash ~/terraform/terraform-force-destroy.sh kosa21 2145  # k8s-worker-01
bash ~/terraform/terraform-force-destroy.sh kosa22 2246  # k8s-worker-02
bash ~/terraform/terraform-force-destroy.sh kosa23 2347  # k8s-worker-03
```

**내부 동작**
1. `qm stop --skiplock`: 실행 중인 VM 강제 중지
2. `qm set --delete scsi0/scsi1/...`: VM config에서 디스크 참조 제거
3. `qm destroy --purge --destroy-unreferenced-disks`: VM 삭제 시도
4. `rm -f /etc/pve/nodes/*/qemu-server/<VMID>.conf`: 설정 파일 강제 삭제 (ghost VM 제거)
5. `lvremove -f pve/<LV>`: 로컬 LV 잔여물 제거 (cloudinit 등)
6. `rbd rm <pool>/<vol>`: Ceph pool에서 orphaned RBD 볼륨 직접 제거


**제거 순서**
> Terraform destroy 없이 force destroy만 실행하면 Proxmox VM은 삭제되지만 state에 VM이 잔류해 이후 apply 시 충돌 발생

1. Terraform으로 먼저 제거 (state + Proxmox 동시 정리)
```bash
bash ~/terraform/terraform-run.sh prod destroy k8s-master
bash ~/terraform/terraform-run.sh prod destroy k8s-worker
```
2. Proxmox에 VM이 잔류하면 force destroy 스크립트로 수동 정리

**정상 제거 vs 강제 제거**

| 상황 | 방법 |
|---|---|
| Terraform state에 존재 | `terraform-run.sh prod destroy <ROLE>` |
| state에 없으나 Proxmox에 잔류 (ghost VM) | `terraform-force-destroy.sh <NODE> <VMID>` |


---

## VM 구성

### VM 보호 (protection)

Proxmox `protection` 플래그를 통해 운영 VM의 **의도치 않은 삭제를 차단**함

- **허용**: CPU, 메모리, 디스크 크기 변경 (in-place update)
- **차단**: `terraform destroy`, `qm destroy`, Proxmox UI 삭제

**적용 대상** (prod): k8s-master, k8s-worker, vault, dns, haproxy, services (nexus/cicd/minio/siem/monitor)
**미적용**: testsec, k8s-worker-pool (재생성 가능한 임시 VM)

**의도적으로 VM을 삭제해야 할 경우**:
```bash
# 1. tfvars에서 protection = false로 변경 후 동기화
bash 03.ansible/03-deploy-to-control.sh

# 2. 보호 해제 apply
bash ~/terraform/terraform-run.sh prod apply <ROLE> <VM명>

# 3. 삭제
bash ~/terraform/terraform-run.sh prod destroy <ROLE> <VM명>
```

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

> 전체 VM 구성은 [VM-SPEC.md](../VM-SPEC.md) 참조

---

## 실행

### 사전 조건

- VMID 9003, 9005 템플릿 존재함
- Proxmox API 토큰 발급 완료함
- `credentials.auto.tfvars` 작성 완료함 (`credentials.auto.tfvars.example` 참조)
- 컨트롤 노드(2210, 172.16.30.7)에서 실행함

### 파일 동기화

**로컬 방식 (현재)**
```bash
# [로컬] rsync로 컨트롤 노드에 업로드
bash 03.ansible/03-deploy-to-control.sh
```

**GitLab 방식 (K8s 운영 중)**
```bash
# [로컬] GitLab에 push (최초 remote 등록 필요)
git push gitlab yjj:main

# [컨트롤 노드] pull (최초: git clone http://gitlab.mgmt.local:8181/root/iac.git ~/iac)
cd ~/iac && git pull
```

> GitLab 설정 및 CI/CD 자동화: [05.cicd/gitlab.md](../05.cicd/gitlab.md)

### 배포

```bash
# 역할별 배포 (컨트롤 노드에서 실행)
bash ~/terraform/terraform-run.sh prod apply dns
bash ~/terraform/terraform-run.sh prod apply k8s-master
bash ~/terraform/terraform-run.sh prod apply k8s-worker

# 특정 VM만 배포
bash ~/terraform/terraform-run.sh prod apply k8s-master k8s-master-01
```

### 동작 순서

1. `template_vm_id`에 따라 9003 또는 9005 풀 클론
2. CPU / 메모리 / 디스크 설정 적용
3. 네트워크: 브리지, VLAN 설정 (방화벽 비활성화)
4. cloud-init: DNS 서버, 고정 IP / 게이트웨이 주입
5. qemu-guest-agent 활성화 확인

---

## 직접 실행 (terraform 명령어)

`terraform-run.sh`으로 처리 불가한 작업은 `env/prod/`에서 직접 실행

> sh는 init·parallelism·auto-target을 자동 처리 → 직접 실행 시 누락 주의

```bash
# [컨트롤 노드]
cd ~/terraform/env/prod

# state 목록 확인
terraform state list

# 기존 VM을 state에 등록 (VM은 살아있고 state만 없을 때)
terraform import -var-file=tfvars/all.tfvars \
  'module.vms.proxmox_virtual_environment_vm.ubuntu["<VM명>"]' "<NODE>/<VMID>"

# VM 강제 재생성 (삭제 후 재배포)
terraform apply \
  -var-file=tfvars/all.tfvars \
  -replace='module.vms.proxmox_virtual_environment_vm.ubuntu["<VM명>"]' \
  -target='module.vms.proxmox_virtual_environment_vm.ubuntu["<VM명>"]' \
  -parallelism=1

# state에서 VM 제거 (Proxmox VM은 유지, state만 제거)
terraform state rm 'module.vms.proxmox_virtual_environment_vm.ubuntu["<VM명>"]'
```

---

## 트러블슈팅

**상황별 대응**

| 증상 | 원인 | 해결 |
|---|---|---|
| destroy 무한 대기 | Ceph RBD 락 충돌 | `terraform-force-destroy.sh` 또는 수동 `rbd rm` |
| apply 시 VMID 충돌 | ghost VM .conf 잔류 | `rm -f /etc/pve/nodes/*/qemu-server/<VMID>.conf` |
| state lock 해제 안 됨 | import/apply 강제 종료 후 lock 잔류 | 프로세스 종료 후 lock 파일 삭제 |

```bash
# [컨트롤 노드] Ceph RBD 락 충돌로 destroy 실패 시
bash ~/terraform/terraform-force-destroy.sh <NODE> <VMID>

# [Proxmox 호스트] ghost VM 강제 제거
rm -f /etc/pve/nodes/*/qemu-server/<VMID>.conf

# [컨트롤 노드] state lock 해제
ps aux | grep terraform
kill -9 <PID>
rm -f ~/terraform/env/prod/.terraform.tfstate.lock.info

# [컨트롤 노드] 특정 VM만 재생성
bash ~/terraform/terraform-run.sh prod apply k8s-master k8s-master-01
```
