# Ceph RBD Storage 설정 가이드

## 1. Ceph RBD Storage 개요

### rbd-storage란?

**RBD (RADOS Block Device)**: Ceph 스토리지의 블록 디바이스

**특징**:
- Distributed Storage (분산 스토리지)
- Data Redundancy (데이터 중복)
- High Availability (고가용성)
- Shared Storage (모든 Proxmox 노드에서 접근 가능)
- Thin Provisioning (실제 사용량만 할당)

### vs local-lvm

| 구분 | local-lvm | rbd-storage |
|------|-----------|-------------|
| 위치 | 각 노드 로컬 | Ceph 클러스터 (분산) |
| 공유 | 불가능 | 가능 |
| HA | 노드 장애 시 VM 마이그레이션만 | 데이터 자체 HA |
| 중복 | 없음 | Ceph replication |
| 성능 | 로컬 디스크 (빠름) | 네트워크 (약간 지연) |
| 용량 | 노드 디스크 크기 | Ceph 클러스터 전체 용량 |

**rbd-storage 장점**:
- 노드 장애 시 VM 마이그레이션 없이도 데이터 보존
- 모든 노드에서 동일한 스토리지 접근
- Live Migration 가능 (VM이 실행 중에 마이그레이션)
- 데이터 중복으로 안정성 향상

---

## 2. Proxmox Ceph 설정

### 2-1. Ceph 클러스터 설치

**Proxmox에서 Ceph 설치**:
```
1. 각 Proxmox 노드에서
   ├── pve1: Ceph → Install
   ├── pve2: Ceph → Install
   ├── pve3: Ceph → Install
   └── pve4: Ceph → Install
   
2. Ceph Monitor 생성
   ├── Datacenter → Ceph → Monitor
   ├── 최소 3개 Monitor (HA)
   └── pve1, pve2, pve3에 Monitor 배치
   
3. Ceph OSD (Object Storage Daemon) 생성
   ├── 각 노드의 디스크를 OSD로 추가
   ├── Datacenter → Ceph → OSD → Create
   └── 예: 각 노드 2개 디스크 → 총 8 OSD
```

### 2-2. Ceph Pool 생성

**Pool 생성**:
```
1. Datacenter → Ceph → Pools → Create
   ├── Name: rbd-storage
   ├── Size: 3 (복제 수, 3개 노드에 복제)
   ├── Min Size: 2 (최소 복제 수)
   └── PG Numbers: 128 (Placement Groups)
   
2. 또는 CLI
   ceph osd pool create rbd-storage 128
   ceph osd pool set rbd-storage size 3
   ceph osd pool set rbd-storage min_size 2
```

### 2-3. RBD Storage 등록

**Proxmox Storage 등록**:
```
1. Datacenter → Storage → Add → RBD
   ├── ID: rbd-storage
   ├── Pool: rbd-storage
   ├── Content: Disk image, Container
   ├── Nodes: All (모든 노드)
   └── KRBD: Enable
   
2. 또는 CLI
   pvesm add rbd rbd-storage --pool rbd-storage --content images,rootdir
```

### 2-4. Storage 확인

**CLI에서 확인**:
```bash
# Storage 목록
pvesm status

# 출력 예시:
NAME        TYPE     STATUS  ACTIVE   CONTENT
rbd-storage rbd      active  yes      images,rootdir
local-lvm   lvm      active  yes      images,rootdir

# Ceph 상태 확인
ceph status

# 출력 예시:
cluster:
  id:     xxxxx
  health: HEALTH_OK
  
services:
  mon: 3 daemons, quorum pve1,pve2,pve3
  osd: 8 osds: 8 up, 8 in
  
data:
  pools:   1 pool, 128 pgs
  objects: 100 objects, 1 GiB
```

---

## 3. VM 디스크 설정

### 3-1. Terraform 설정

**terraform.tfvars**:
```hcl
storage = "rbd-storage"
```

**terraform/modules/proxmox-vm/main.tf**:
```hcl
disk {
  slot     = "scsi0"
  type     = "disk"
  storage  = "rbd-storage"  # Ceph RBD
  size     = "${var.disk_size}G"
  iothread = 1
}
```

### 3-2. VM 생성 과정

**Terraform 작동**:
```
1. Template에서 Clone
   ├── Template (9001): local-lvm 또는 rbd-storage
   
2. New VM Disk
   ├── Clone된 VM의 disk를 rbd-storage로 생성
   └── Thin provisioning (실제 사용량만)
   
3. Ceph 배치
   ├── Ceph가 disk를 OSD에 분산 배치
   ├── 3개 노드에 복제 (size=3)
   └── 하나의 OSD 장애 시 자동 복구
```

### 3-3. Disk 크기 설정

**Percona**:
- Disk: 60GB
- 실제 사용: Thin provisioning
- 필요시 확장 가능

**HAProxy**:
- Disk: 20GB
- 로그, 설정 저장

**ProxySQL**:
- Disk: 30GB
- 쿼리 캐시, 설정 저장

---

## 4. HA (High Availability) with Ceph

### 4-1. 노드 장애 시나리오

**local-lvm (로컬 스토리지)**:
```
pve1 장애:
  ├── pve1의 local-lvm에 있는 VM disk 접근 불가
  ├── Proxmox HA: VM을 다른 노드로 마이그레이션
  ├── 다른 노드에 VM 시작
  └── disk는 새 노드의 local-lvm으로 복사 (시간 소요)
```

**rbd-storage (Ceph)**:
```
pve1 장애:
  ├── pve1의 OSD 장애
  ├── Ceph: pve2, pve3의 OSD에서 데이터 복구
  ├── VM disk는 이미 pve2, pve3에 복제됨
  ├── Proxmox HA: VM을 다른 노드로 마이그레이션
  ├── 다른 노드에서 rbd-storage disk 접근 (즉시)
  └── VM 빠른 시작 (disk 복사 불필요)
```

**장점**:
- VM 마이그레이션 시간 단축
- 데이터 중복 보장
- 노드 장애 시 데이터 손실 없음

### 4-2. Live Migration

**local-lvm**:
- VM을 Stop → Migration → Start
- Migration 시간: disk 크기에 따라 다름
- Service 중단 발생

**rbd-storage**:
- VM이 Running 상태에서 Migration
- Network overhead만 있음
- Service 중단 없음
- Migration 시간: 수 초

**실행**:
```bash
# Live Migration
qm migrate 100 pve2 --online

# 또는 GUI
# VM → Migrate → Target: pve2 → Mode: Online
```

---

## 5. Ceph 성능 최적화

### 5-1. OSD 배치

**最佳配置**:
```
각 노드:
  ├── SSD/NVMe: Journal + OSD
  └── HDD: OSD (bulk storage)
  
예시 (4 노드):
  pve1: SSD (journal) + 2x HDD (OSD)
  pve2: SSD (journal) + 2x HDD (OSD)
  pve3: SSD (journal) + 2x HDD (OSD)
  pve4: SSD (journal) + 2x HDD (OSD)
  
총: 8 OSD + 4 Journal
```

### 5-2. Network 설정

**Ceph Network**:
```
1. Separate Network (Separation)
   ├── Public Network: Client access
   └── Cluster Network: OSD replication
   
2. 또는 Single Network (Simple)
   └── VLAN 사용으로 분리
   
예시:
  VLAN 40: Ceph Public Network (172.16.40.x)
  VLAN 41: Ceph Cluster Network (172.16.41.x)
```

### 5-3. PG (Placement Groups) 설정

**PG 수 계산**:
```
Target PGs per OSD: 100-200

예시:
  OSDs: 8
  Pool size: 3
  Target PGs per OSD: 100
  
Total PGs = (OSDs * Target PGs) / Pool size
          = (8 * 100) / 3
          = 266
          
Round up: 256 (power of 2)
```

**PG 설정**:
```bash
ceph osd pool set rbd-storage pg_num 256
ceph osd pool set rbd-storage pgp_num 256
```

---

## 6. Ceph 모니터링

### 6-1. Ceph Status

**CLI에서 모니터링**:
```bash
# Overall status
ceph status

# Health detail
ceph health detail

# OSD status
ceph osd tree

# Pool usage
ceph df

# 출력 예시:
POOL         ID   USED    %USED  OBJECTS
rbd-storage  1    100GiB  10.00  1000
```

### 6-2. Proxmox GUI

**Ceph Monitoring**:
```
Datacenter → Ceph
  ├── Monitor: Monitor 상태
  ├── OSD: OSD 상태, Disk 사용량
  ├── Pools: Pool 상태, 사용량
  └── Disks: 물리 Disk 상태
```

### 6-3. VM Disk 확인

**CLI에서 확인**:
```bash
# VM disk 위치
qm config 100 | grep scsi0

# 출력:
scsi0: rbd-storage:vm-100-disk-0,size=60G

# RBD image 확인
rbd list rbd-storage

# 출력:
vm-100-disk-0
vm-101-disk-0
vm-102-disk-0
```

---

## 7. 문제 해결

### 7-1. Ceph Health Warning

**Health WARN**:
```bash
ceph health detail

# 출력 예시:
HEALTH_WARN: 1 OSD is down

# OSD 확인
ceph osd tree

# OSD start
systemctl start ceph-osd@1
```

### 7-2. VM Disk 접근 실패

**VM 시작 실패**:
```
Error: rbd-storage:vm-100-disk-0 not found

확인:
  ├── Ceph OSD 상태 확인
  ├── rbd image 확인
  └── Pool 상태 확인
```

**해결**:
```bash
# OSD 확인
ceph osd status

# OSD start
ceph osd start 1

# rbd image 확인
rbd info rbd-storage/vm-100-disk-0
```

### 7-3. Storage Full

**Storage usage > 80%**:
```bash
ceph df

# Pool 사용량 확인
POOL         USED    %USED
rbd-storage  800GiB  85.00  # Warning!

# OSD 추가 (디스크 추가)
pve4 → Ceph → OSD → Create

# 또는 Pool size 감소 (위험)
ceph osd pool set rbd-storage size 2
```

---

## 8. Backup & Recovery

### 8-1. VM Backup

**Proxmox Backup**:
```bash
# Backup to external storage
vzdump 100 --storage pbs-backup --mode snapshot

# 또는 GUI
# VM → Backup → Backup now
```

**Ceph Snapshots**:
```bash
# RBD snapshot
rbd snap create rbd-storage/vm-100-disk-0@backup-20250511

# Snapshot list
rbd snap list rbd-storage/vm-100-disk-0

# Rollback
rbd snap rollback rbd-storage/vm-100-disk-0@backup-20250511
```

### 8-2. Disaster Recovery

**Ceph OSD 전체 장애**:
```
Scenario: 모든 OSD 장애

Recovery:
  1. Ceph Monitor 복구 (Backup에서)
  2. OSD 재구성
  3. Pool 복구
  4. VM disk 복구
```

**Plan**:
- Ceph Monitor backup (정기)
- OSD journal backup
- External backup storage (PBS)
- Disaster recovery plan 문서화

---

## 9. rbd-storage 사용 시 고려사항

### 9-1. Network Dependency

**네트워크 필요**:
- Ceph OSD 간 통신 (Cluster Network)
- Client ↔ OSD 통신 (Public Network)
- Network 장애 → Storage 장애

**대책**:
- Network redundancy (Bonding)
- Separate network (VLAN)
- Network monitoring

### 9-2. 성능

**로컬 스토리지 vs Ceph**:
- local-lvm: 로컬 disk I/O (빠름)
- rbd-storage: Network I/O (약간 지연)

**성능 향상**:
- SSD/NVMe OSD
- Network optimization (10G+)
- PG tuning
- Cache 설정

### 9-3. 복잡성

**관리 복잡성 증가**:
- Ceph 설정
- OSD 관리
- Monitor 관리
- Network 설정

**장점으로 상쇄**:
- HA
- Data redundancy
- Shared storage
- Live migration

---

## 10. Proxmox Ceph 설정 체크리스트

### Ceph 설치

- [ ] 각 노드에 Ceph install
- [ ] Ceph Monitor 생성 (최소 3개)
- [ ] Ceph OSD 생성 (각 노드)
- [ ] Ceph Pool 생성 (rbd-storage)
- [ ] Pool replication 설정 (size=3)
- [ ] RBD storage 등록 (Proxmox)

### Storage 설정

- [ ] Storage ID: rbd-storage
- [ ] Content: Disk image, Container
- [ ] Nodes: All nodes
- [ ] KRBD: Enable
- [ ] Thin provision: Enable

### Terraform 설정

- [ ] storage = "rbd-storage"
- [ ] Template storage: rbd-storage 또는 local-lvm
- [ ] VM disk: rbd-storage

### 테스트

- [ ] VM 생성 테스트
- [ ] VM Live Migration 테스트
- [ ] Ceph status 확인
- [ ] VM disk 확인 (rbd list)
- [ ] OSD 장애 시나리오 테스트

---

## 11. 요약

### rbd-storage 설정

```hcl
# Terraform
storage = "rbd-storage"
```

### Ceph Pool 설정

```
Name: rbd-storage
Size: 3 (replication)
Min Size: 2
PG: 128-256
```

### Proxmox Storage 등록

```
ID: rbd-storage
Type: RBD
Pool: rbd-storage
Content: images,rootdir
Nodes: All
```

### VM Disk

```
Type: RBD (Ceph)
Storage: rbd-storage
Thin provisioning: Yes
Replication: 3 nodes
```

### HA Benefit

- 노드 장애 시 빠른 VM 마이그레이션
- 데이터 중복 보장
- Live Migration 가능
- 데이터 손실 없음

### 다음 단계

1. Ceph 클러스터 설치 (4 노드)
2. rbd-storage pool 생성
3. Proxmox storage 등록
4. Terraform 실행 (rbd-storage 사용)
5. VM 생성 및 테스트
6. Live Migration 테스트
7. OSD 장애 테스트