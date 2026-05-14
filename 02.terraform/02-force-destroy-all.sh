#!/bin/bash

# Proxmox VM 강제 삭제 스크립트
# Terraform destroy 실패 시 남아있는 VM을 강제로 정리
#
# [2026-05-14] 최초 작성
#
# 실행: 로컬(노트북) 환경에서 실행
# 사용법: bash 02.terraform/02-force-destroy-all.sh [TARGET]
# 예시:   bash 02.terraform/02-force-destroy-all.sh kosa21

set -euo pipefail

# 프록스목스 노드 관리 IP (192.168.34.2 ~ .5)
declare -A NODE_IPS=(
  [kosa21]="192.168.34.2"
  [kosa22]="192.168.34.3"
  [kosa23]="192.168.34.4"
  [kosa24]="192.168.34.5"
)
SSH_USER="kosa"
SSH_PASS="kosa1004"

# ── 노드별 삭제 대상 VMID ─────────────────────────────────────
declare -A NODE_VMIDS=(
  [kosa21]="2115 2130 2141 2150 2131 2145"        # vault1, master-01, worker-01, registry (새 VMID 추가)
  [kosa22]="2211 2226 2231 2242 2270 2232 2246"   # dns1, haproxy1, master-02, worker-02, siem (새 VMID 추가)
  [kosa23]="2312 2327 2332 2343 2380 2333 2347"   # dns2, haproxy2, master-03, worker-03, monitoring (새 VMID 추가)
  [kosa24]="2416 2440 2455"             # vault2, worker-plat, cicd
)

TARGET="${1:-all}"

destroy_vm() {
  local node="$1"
  local ip="${NODE_IPS[$node]}"
  local vmids="${NODE_VMIDS[$node]}"

  local socket="/tmp/pve_destroy_${node}.sock"
  local ssh_opts="-o ControlMaster=auto -o ControlPath=${socket} -o ControlPersist=60 -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o PubkeyAuthentication=no"

  echo ""
  echo ">>> [$node] ($ip) 처리 시작"
  
  echo "  [INFO] SSH 연결 초기화 (최초 1회 비밀번호 '$SSH_PASS' 입력 필요)"
  if ! ssh $ssh_opts "${SSH_USER}@${ip}" "echo connected" >/dev/null; then
    echo "  [FAIL] $node 에 SSH 연결을 실패했습니다."
    HAS_ERRORS=1
    return
  fi

  for vmid in $vmids; do
    echo "  - VMID $vmid 상태 확인 중..."
    if ssh $ssh_opts "${SSH_USER}@${ip}" "
      if echo \"$SSH_PASS\" | sudo -S qm status $vmid > /dev/null 2>&1; then
        echo 'stopping'
        echo \"$SSH_PASS\" | sudo -S qm stop $vmid --skiplock 2>/dev/null || true
        sleep 2
        echo \"$SSH_PASS\" | sudo -S qm destroy $vmid --purge --destroy-unreferenced-disks 1 > /dev/null 2>&1
      else
        echo 'not_found'
      fi
    " | grep -q "not_found"; then
      echo "    [SKIP] VMID $vmid 존재하지 않음"
    elif [ ${PIPESTATUS[0]} -eq 0 ]; then
      echo "    [OK] VMID $vmid 삭제 완료"
    else
      echo "    [FAIL] VMID $vmid 처리 실패 (실행 오류)"
      HAS_ERRORS=1
    fi
  done

  # 소켓 정리
  ssh -O exit -o ControlPath="${socket}" "${SSH_USER}@${ip}" 2>/dev/null || true
}

# 실행
echo "[INFO] Proxmox VM 강제 삭제 시작 (대상: ${TARGET})"

HAS_ERRORS=0
STEP=1

for node in "${!NODE_VMIDS[@]}"; do
  if [[ "$TARGET" == "all" || "$TARGET" == "$node" ]]; then
    echo "[$STEP/4] $node (${NODE_IPS[$node]}) 처리 중..."
    destroy_vm "$node"
    ((STEP++))
  fi
done

echo ""
if [ $HAS_ERRORS -eq 0 ]; then
  echo "작업이 완료되었습니다. Proxmox GUI에서 결과를 확인하세요."
else
  echo "[FAIL] 일부 작업이 실패했습니다. 에러 메시지를 확인하고 수동으로 점검하세요."
  exit 1
fi
