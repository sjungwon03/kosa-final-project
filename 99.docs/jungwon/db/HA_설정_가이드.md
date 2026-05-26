# HA (High Availability) 설정 가이드

## 1. Proxmox HA 개요

### HA 작동 방식

**Proxmox HA**: 노드 장애 시 VM 자동 마이그레이션

**구성 요소**:
- **HA Group**: VM 그룹 정의
- **HA Resource**: HA 관리 대상 VM
- **HA State**: started, stopped, ignored

**작동 원리**:
```
Proxmox HA Manager (각 노드):
  ├── HA Group 정보 관리
  ├── 노드 장애 감지 (heartbeat)
  ├── HA Resource 상태 확인
  └── VM 마이그레이션 실행
  
노드 장애 시:
  1. HA Manager가 장애 노드 감지
  2. HA Group의 다른 노드 선택
  3. VM 마이그레이션 (rbd-storage: Live Migration)
  4. VM 재시작
  5. 서비스 계속 작동
```

---

## 2. Terraform HA 설정

### 2-1. HA 변수

**terraform.tfvars**:
```hcl
ha_enabled     = true        # HA 활성화
ha_group       = "percona-ha" # HA 그룹 이름
```

### 2-2. Terraform HA 구현

**proxmox_vm_qemu 리소스**:
```hcl
resource "proxmox_vm_qemu" "vm" {
  ...
  
  # HA 설정 (Proxmox provider v2.9.x)
  ha = var.ha_enabled ? "started" : "ignored"
}
```

**ha 필드값**:
- `started`: VM이 HA 관리됨, 실행 상태 유지
- `stopped`: VM이 HA 관리됨, 정지 상태 유지
- `ignored`: HA 관리 안 함

### 2-3. HA Group (수동 생성)

**Proxmox CLI에서 HA Group 생성**:
```bash
# HA Group 생성
ha-manager add-group percona-ha \
  --nodes pve1,pve2,pve3,pve4 \
  --restricted 1

# 옵션:
# --nodes: HA 그룹에 포함된 노드
# --restricted: 그룹 노드만 사용 (1=Yes)
```

**HA Group 확인**:
```bash
ha-manager group list

# 출력:
NAME          NODES               RESTRICTED  TYPE
percona-ha    pve1,pve2,pve3,pve4 1           group
```

---

## 3. HA 배포 과정

### Step 1: HA Group 생성 (사전 준비)

```bash
# Proxmox 노드에서 실행
ha-manager add-group percona-ha \
  --nodes pve1,pve2,pve3,pve4 \
  --restricted 1

# 확인
ha-manager group list
ha-manager status
```

### Step 2: Terraform 실행

```bash
cd terraform

# terraform.tfvars 설정
vim terraform.tfvars
  ├── ha_enabled = true
  └── ha_group = "percona-ha"

# Terraform 초기화
terraform init

# 실행
terraform apply

# Terraform 작동:
# 1. VM 생성
# 2. ha = "started" 설정
# 3. Proxmox HA Manager가 VM을 HA 관리
# 4. VM이 HA 그룹에 추가됨
```

### Step 3: HA 확인

```bash
# HA Resource 확인
ha-manager resource list

# 출력:
VMID  TYPE  STATE    GROUP       NODE
100   vm    started  percona-ha  pve1
101   vm    started  percona-ha  pve2
102   vm    started  percona-ha  pve3
103   vm    started  percona-ha  pve1
104   vm    started  percona-ha  pve2
105   vm    started  percona-ha  pve3
106   vm    started  percona-ha  pve4

# HA Status 확인
ha-manager status

# 출력:
QUORATOR: pve1
MASTER: pve1
SLAVE: pve2, pve3, pve4
```

---

## 4. HA 작동 시나리오

### 4-1. 노드 장애 시

**Scenario**: pve1 장애

```
HA Manager 작동:
  1. pve1 heartbeat 실패 감지
  2. pve1의 HA Resource 확인
     ├── VM 100 (pxc-1)
     ├── VM 103 (haproxy-1)
  3. HA Group에서 다른 노드 선택
     ├── VM 100 → pve2
     ├── VM 103 → pve3
  4. VM 마이그레이션
     ├── rbd-storage: Live Migration (즉시)
     ├── VM 100: pve1 → pve2
     ├── VM 103: pve1 → pve3
  5. VM 재시작
  6. HA Resource 업데이트
     ├── VM 100: node=pve2
     ├── VM 103: node=pve3
  7. 서비스 계속 작동
```

**Percona 클러스터 복구**:
```
VM 100 (pxc-1) 장애 → pve2에서 재시작:
  1. pxc-1 VM 시작
  2. Percona 서비스 시작
  3. Galera cluster 재가입
  4. IST로 데이터 동기화
  5. wsrep_cluster_size: 3
  6. 클러스터 정상 작동
```

### 4-2. VM 장애 시

**Scenario**: VM 내부 장애 (Percona crash)

```
HA Manager 작동:
  1. VM 실행 상태 모니터링
  2. VM 장애 감지 (VM stopped)
  3. HA State: started → VM 재시작
  4. VM 재시작 시도 (max_restart: 2)
     ├── 1차 시도: restart
     ├── 성공: VM 실행
     └── 실패: 2차 시도
  5. max_restart 초과 → VM relocate
     ├── 다른 노드로 마이그레이션
     └── VM 재시작
```

### 4-3. 다중 노드 장애 시

**Scenario**: pve1, pve2 장애

```
HA Manager 작동:
  1. pve1, pve2 heartbeat 실패
  2. HA Resource 확인
     ├── VM 100, 101 (pxc-1, pxc-2)
     ├── VM 103, 104 (haproxy-1, haproxy-2)
  3. 남은 노드: pve3, pve4
  4. VM 마이그레이션
     ├── VM 100 → pve3
     ├── VM 101 → pve4
     ├── VM 103 → pve3
     ├── VM 104 → pve4
  5. VM 재시작
  6. Percona 클러스터 재구성
     ├── pxc-1, pxc-2 → pve3, pve4
     ├── pxc-3 (pve3) 정상
     ├── wsrep_cluster_size: 3
  7. 서비스 계속 작동
```

---

## 5. HA 설정 옵션

### 5-1. HA State

| State | 설명 |
|-------|------|
| `started` | VM 실행, HA 관리 (장애 시 재시작/마이그레이션) |
| `stopped` | VM 정지, HA 관리 (장애 시 마이그레이션만) |
| `ignored` | HA 관리 안 함 (장애 시 자동 복구 없음) |

**Terraform 설정**:
```hcl
# 모든 VM HA 활성화
ha = "started"

# 특정 VM HA 비활성화
ha = "ignored"
```

### 5-2. HA Group Options

**CLI 옵션**:
```bash
ha-manager add-group <group-name> \
  --nodes <node1,node2,...>  # 그룹 노드
  --restricted 1             # 그룹 노드만 사용
  --type group               # 그룹 타입
```

**restricted=1**: 그룹 노드만 사용
- 장애 시 그룹 내 노드로만 마이그레이션
- 외부 노드 사용 안 함

**restricted=0**: 모든 노드 사용 가능

### 5-3. HA Resource Options

**CLI 옵션**:
```bash
ha-manager add <type>:<vmid> \
  --group <group-name>       # HA 그룹
  --state started            # HA state
  --max_relocate 2           # 최대 마이그레이션 수
  --max_restart 2            # 최대 재시작 수
```

**max_relocate**: 노드 장애 시 최대 마이그레이션 수
**max_restart**: VM 장애 시 최대 재시작 수

---

## 6. HA 모니터링

### 6-1. HA Status 확인

```bash
# HA Manager 상태
ha-manager status

# 출력:
QUORATOR: pve1
MASTER: pve1
SLAVE: pve2, pve3, pve4

# HA Group 상태
ha-manager group list

# HA Resource 상태
ha-manager resource list

# 특정 Resource 상태
ha-manager resource show vm:100
```

### 6-2. HA 로그 확인

```bash
# HA Manager 로그
journalctl -u pve-ha-manager -f

# HA CRM 로그
journalctl -u pve-ha-crm -f

# HA LRM 로그
journalctl -u pve-ha-lrm -f

# 전체 HA 로그
journalctl -u pve-ha-* -f
```

### 6-3. Proxmox GUI

```
Datacenter → HA
  ├── Groups: HA 그룹 목록
  ├── Resources: HA Resource 목록
  └── Status: HA Manager 상태
```

---

## 7. HA 테스트

### 7-1. 노드 장애 테스트

```bash
# pve1 장애 시뮬레이션 (SSH disconnect)
ssh root@pve1
systemctl stop pve-cluster

# HA Manager 작동 확인
ha-manager status

# VM 마이그레이션 확인
ha-manager resource list

# VM 상태 확인
qm list

# 서비스 연결 테스트
mysql -h172.16.20.30 -P3306 -u root -p
```

### 7-2. VM 장애 테스트

```bash
# VM 정지 (HA에 있는 VM)
qm stop 100

# HA Manager 재시작 확인
ha-manager resource show vm:100

# 출력:
state: started
node: pve2 (마이그레이션됨)
restarts: 1

# VM 확인
qm list | grep 100
# VM 100 running on pve2
```

### 7-3. HA Disable 테스트

```bash
# HA 비활성화
ha-manager resource update vm:100 --state ignored

# VM 정지
qm stop 100

# HA Manager 작동 안 함 (ignored)
ha-manager resource show vm:100
# state: ignored

# VM 재시작 안 됨
qm list | grep 100
# VM 100 stopped

# HA 활성화
ha-manager resource update vm:100 --state started

# VM 재시작됨
qm list | grep 100
# VM 100 running
```

---

## 8. HA 문제 해결

### 8-1. HA Manager 시작 안 됨

**확인**:
```bash
systemctl status pve-ha-manager

# Active: inactive
```

**해결**:
```bash
systemctl start pve-ha-manager
systemctl enable pve-ha-manager
```

### 8-2. HA Resource 실패

**확인**:
```bash
ha-manager resource show vm:100

# state: failed
# error: ...
```

**해결**:
```bash
# HA Resource reset
ha-manager resource reset vm:100

# 또는 VM 수동 시작
qm start 100

# HA 상태 확인
ha-manager resource show vm:100
# state: started
```

### 8-3. Quorum Lost

**확인**:
```bash
ha-manager status

# QUORATOR: none
# Error: No quorum
```

**해결**:
```bash
# Corosync 확인
systemctl status corosync

# Corosync 재시작
systemctl restart corosync

# Quorum 확인
corosync-quorumtool -s

# HA Manager 재시작
systemctl restart pve-ha-manager
```

---

## 9. HA Best Practices

### 9-1. HA Group 설정

**권장**:
- 최소 3 노드 HA Group (Quorum)
- restricted=1 (그룹 노드만 사용)
- 모든 Proxmox 노드 포함

### 9-2. HA Resource 설정

**권장**:
- 모든 중요 VM HA 활성화
- max_relocate: 2
- max_restart: 2

**비권장**:
- HA를 Test VM에 적용
- HA를 Template에 적용

### 9-3. Storage for HA

**권장**:
- rbd-storage (Ceph): Live Migration 가능
- Shared storage: 모든 노드 접근 가능

**비권장**:
- local-lvm: 마이그레이션 시 disk 복사 필요

### 9-4. Network for HA

**권장**:
- Separate network for HA heartbeat
- Redundant network (bonding)

**필요 포트**:
- Corosync: UDP 5405, 5406
- HA Manager: TCP 80

---

## 10. HA 설정 체크리스트

### 사전 준비

- [ ] Proxmox 클러스터 (4 노드)
- [ ] Ceph cluster (rbd-storage)
- [ ] Corosync 설정 확인
- [ ] HA Group 생성

### HA Group 생성

```bash
ha-manager add-group percona-ha \
  --nodes pve1,pve2,pve3,pve4 \
  --restricted 1
```

- [ ] HA Group 확인
- [ ] HA Manager 상태 확인

### Terraform 설정

- [ ] ha_enabled = true
- [ ] ha_group = "percona-ha"
- [ ] terraform apply

### HA 확인

- [ ] ha-manager resource list
- [ ] ha-manager status
- [ ] VM HA state 확인
- [ ] 노드 장애 테스트

---

## 11. HA 설정 요약

### Terraform 설정

**terraform.tfvars**:
```hcl
ha_enabled     = true
ha_group       = "percona-ha"
```

**proxmox_vm_qemu**:
```hcl
ha = "started"  # HA 활성화
```

### Proxmox CLI

**HA Group 생성**:
```bash
ha-manager add-group percona-ha \
  --nodes pve1,pve2,pve3,pve4 \
  --restricted 1
```

**HA Resource 확인**:
```bash
ha-manager resource list
ha-manager status
```

### HA 작동

**노드 장애 시**:
```
1. HA Manager 감지
2. VM 마이그레이션 (rbd-storage: Live)
3. VM 재시작
4. 서비스 계속
```

**VM 장애 시**:
```
1. HA Manager 감지
2. VM 재시작 (max_restart: 2)
3. 실패 시 마이그레이션 (max_relocate: 2)
```

### HA Benefits

- 노드 장애 시 자동 복구
- VM 장애 시 자동 재시작
- 서비스 연속성 보장
- 데이터 손실 방지 (rbd-storage)

---

## 12. 다음 단계

1. **HA Group 생성** (Proxmox CLI)
2. **Terraform 설정** (ha_enabled=true)
3. **Terraform 실행** (VM 생성 + HA 활성화)
4. **HA 확인** (ha-manager status)
5. **HA 테스트** (노드 장애 시뮬레이션)
6. **모니터링 설정** (HA logs)
7. **Documentation** (HA 설정 로그)