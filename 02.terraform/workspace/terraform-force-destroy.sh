#!/bin/bash

# Proxmox VM 강제 삭제 스크립트 (RBD 락 및 유령 VM 해결용)
# 실행: 컨트롤 노드 또는 Proxmox 접근 가능한 로컬 환경
#
# [변경 이력]
# [2026-05-15] RBD 디스크 누락 케이스 처리 추가 (destroy 전 디스크 ref 제거 + 로컬 LV 강제 삭제)
# [2026-05-15] VM 존재 여부 사전 확인 추가 (없는 VMID에 성공 보고하던 버그 수정)
# [2026-05-18] SSH_OPTS에 id_proxmox 키 추가 (컨트롤 노드 → Proxmox 키 인증)
# [2026-05-18] VMID 필수 인자로 변경 (전체 삭제 방지)
# [2026-05-18] 존재 확인 기준을 qm list → config 파일로 변경 (ghost VM 처리)
# [2026-05-18] 단계별 상세 로깅 추가 (각 단계 실행 결과 출력)
# [2026-05-18] SSH 블록 내 trap 에러 핸들러 추가 (실패 라인/명령 출력)
# [2026-05-18] Ceph RBD 볼륨 직접 제거 단계 추가 (00-force-destroy-vm.sh 패턴 반영)

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <NODE_NAME> <VMID>"
  echo "Example: $0 kosa21 2131"
  echo "ERROR: VMID는 필수 인자입니다. (전체 삭제 방지)"
  exit 1
fi

NODE=$1
VMID_TARGET=$2

# 프록스목스 노드 관리 IP
declare -A NODE_IPS=(
  [kosa21]="192.168.34.2"
  [kosa22]="192.168.34.3"
  [kosa23]="192.168.34.4"
  [kosa24]="192.168.34.5"
)

IP=${NODE_IPS[$NODE]:-}
if [ -z "$IP" ]; then
  echo "ERROR: Unknown node $NODE"
  exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -i $HOME/.ssh/id_proxmox"

echo "[INFO] $NODE ($IP) 리소스 강제 정리 시작..."

ssh $SSH_OPTS root@$IP "
  trap 'echo \"[ERROR] line \${LINENO}: \${BASH_COMMAND}\" >&2' ERR
  VMIDS=\"$VMID_TARGET\"

  for vmid in \$VMIDS; do
    # config 파일 기준으로 존재 확인 (find 사용 — ls+glob은 pipefail 환경에서 오탐 발생)
    conf_path=\$(find /etc/pve/nodes/ -maxdepth 3 -name \"\${vmid}.conf\" -path \"*/qemu-server/*\" 2>/dev/null | head -1)
    if [ -z \"\$conf_path\" ]; then
      echo \"  - VMID \$vmid: config 파일 없음 — skip\"
      continue
    fi

    echo \"  - Processing VMID: \$vmid\"

    # 1. 강제 중지 (락 무시)
    echo \"    [1/6] qm stop \$vmid --skiplock\"
    if qm stop \$vmid --skiplock 2>&1; then
      echo \"          stopped\"
    else
      echo \"          already stopped or not running (ignored)\"
    fi

    # 2. RBD 디스크 참조 제거 (디스크가 이미 없어도 config에서 제거 — 없으면 무시)
    echo \"    [2/6] disk ref 제거 (scsi0~2, virtio0, sata0, ide2)\"
    for disk in scsi0 scsi1 scsi2 virtio0 sata0 ide2; do
      result=\$(qm set \$vmid --delete \$disk 2>&1) && echo \"          \$disk: removed\" || echo \"          \$disk: skip (\$result)\"
    done

    # 3. VM 삭제 시도
    echo \"    [3/6] qm destroy \$vmid --purge --destroy-unreferenced-disks 1\"
    if qm destroy \$vmid --purge --destroy-unreferenced-disks 1 2>&1; then
      echo \"          [OK] qm destroy success\"
    else
      echo \"          [WARN] qm destroy failed — conf 강제 삭제로 진행\"
    fi

    # 4. 설정 파일 강제 삭제 (유령 VM 제거 핵심)
    echo \"    [4/6] conf 파일 강제 삭제\"
    for conf in \$(ls /etc/pve/nodes/*/qemu-server/\${vmid}.conf 2>/dev/null); do
      rm -f \"\$conf\"
      echo \"          removed: \$conf\"
    done

    # 5. 로컬 LV 강제 삭제 (cloudinit 등 local-lvm 잔여물)
    echo \"    [5/6] 로컬 LV 잔여물 확인\"
    lv_found=0
    for lv in \$(lvs --noheadings -o lv_name pve 2>/dev/null | grep \"vm-\${vmid}\" | awk '{print \$1}'); do
      lvremove -f pve/\$lv 2>&1 && echo \"          [OK] LV pve/\$lv removed\" || echo \"          [WARN] LV pve/\$lv 제거 실패\"
      lv_found=1
    done
    [ \$lv_found -eq 0 ] && echo \"          없음\"

    # 6. Ceph RBD 볼륨 직접 제거 (pool에서 orphaned 볼륨 정리)
    echo \"    [6/6] Ceph RBD 볼륨 확인\"
    rbd_found=0
    while IFS= read -r rbd_pool; do
      for vol in \$(rbd ls \"\${rbd_pool}\" 2>/dev/null | grep \"^vm-\${vmid}-\"); do
        rbd rm \"\${rbd_pool}/\${vol}\" 2>&1 && echo \"          [OK] rbd removed: \${rbd_pool}/\${vol}\" || echo \"          [WARN] rbd rm failed: \${rbd_pool}/\${vol}\"
        rbd_found=1
      done
    done < <(grep -A10 '^rbd:' /etc/pve/storage.cfg | awk '/^\s*pool\s/{print \$2}')
    [ \$rbd_found -eq 0 ] && echo \"          없음 또는 이미 제거됨\"

    echo \"    [OK] VMID \$vmid cleanup done\"
  done
"

echo "[INFO] 작업 완료"
