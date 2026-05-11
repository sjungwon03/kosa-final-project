# Storage 설정 요약

## Storage Backend: rbd-storage (Ceph RBD)

**모든 VM 디스크**: rbd-storage 사용

### Terraform Configuration

```hcl
storage = "rbd-storage"
```

### VM Disk Configuration

**Percona VMs**:
- Disk: 60GB (rbd-storage)
- Thin provisioning
- Replication: 3 nodes

**HAProxy VMs**:
- Disk: 20GB (rbd-storage)
- Thin provisioning

**ProxySQL VMs**:
- Disk: 30GB (rbd-storage)
- Thin provisioning

### Ceph Pool Configuration

**Pool Name**: rbd-storage
**Replication Size**: 3 (모든 데이터 3개 노드에 복제)
**Min Size**: 2 (최소 2개 노드에 복제)
**Placement Groups**: 128-256

### Benefits

1. **High Availability**:
   - 노드 장애 시 VM 빠른 마이그레이션
   - 데이터 이미 다른 노드에 복제
   - VM 시작 시 disk 복사 불필요

2. **Data Redundancy**:
   - 3개 노드에 데이터 복제
   - 노드 장애 시 자동 복구
   - 데이터 손실 없음

3. **Shared Storage**:
   - 모든 Proxmox 노드에서 접근 가능
   - Live Migration 가능
   - VM이 실행 중에 마이그레이션

4. **Thin Provisioning**:
   - 실제 사용량만 할당
   - Disk 크기 확장 가능
   - Storage 효율성

### rbd-storage vs local-lvm

| Feature | local-lvm | rbd-storage |
|---------|-----------|-------------|
| Location | 각 노드 로컬 | Ceph 클러스터 |
| Shared | No | Yes |
| HA | Migration only | Data replication |
| Redundancy | None | 3x replication |
| Migration | Stop & Copy | Live Migration |
| Performance | Local I/O | Network I/O |

### Proxmox Ceph Setup Required

Before Terraform deployment:

1. **Install Ceph** on all Proxmox nodes (pve1-4)
2. **Create Ceph Monitor** (minimum 3)
3. **Create Ceph OSD** (add disks to each node)
4. **Create Pool**: rbd-storage
5. **Register Storage**: rbd-storage in Proxmox
6. **Verify**: `ceph status` (HEALTH_OK)

### CLI Commands

```bash
# Check storage
pvesm status

# Check Ceph status
ceph status

# Check OSD tree
ceph osd tree

# Check pool usage
ceph df

# Check VM disks
qm config <VMID> | grep scsi0
rbd list rbd-storage
```

### Migration Example

```bash
# Live Migration with rbd-storage
qm migrate 100 pve2 --online

# VM continues running during migration
# Network overhead only (no disk copy)
# Migration time: seconds
```

### Troubleshooting

**VM Start Failure**:
```bash
# Check Ceph status
ceph status

# Check OSD
ceph osd tree

# Check rbd image
rbd info rbd-storage/vm-100-disk-0
```

**Storage Full**:
```bash
# Check usage
ceph df

# Add OSD (more disks)
Datacenter → Ceph → OSD → Create
```

### Configuration Files

**Terraform**:
- `terraform/environments/production/terraform.tfvars`
  ```hcl
  storage = "rbd-storage"
  ```

**Ansible**:
- Not required (storage is VM-level)

**Proxmox**:
- Datacenter → Storage → rbd-storage
- Datacenter → Ceph → Pool: rbd-storage

### Documentation

See `docs/Ceph_RBD_설정.md` for detailed Ceph setup guide.