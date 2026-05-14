#!/bin/bash
# force-destroy-all.sh — 프록스목스 VM 강제 삭제 스크립트
# 테라폼 destroy 실패 후 실제 노드에 남아있는 VM을 직접 제거할 때 사용
# 컨트롤 노드에서 실행: bash ~/workspace/terraform/force-destroy-all.sh
#
# 사용법:
#   bash force-destroy-all.sh         # 전체 삭제
#   bash force-destroy-all.sh kosa21  # 특정 노드만 삭제

set -euo pipefail

# ── 노드별 SSH 접속 정보 ──────────────────────────────────────
# 프록스목스 노드 관리 IP (192.168.34.x 대역)
declare -A NODE_IPS=(
  [kosa21]="192.168.34.21"
  [kosa22]="192.168.34.22"
  [kosa23]="192.168.34.23"
  [kosa24]="192.168.34.24"
)
SSH_USER="root"

# ── 노드별 삭제 대상 VMID ─────────────────────────────────────
declare -A NODE_VMIDS=(
  [kosa21]="2115 2130 2141 2150"        # vault1, master-01, worker-01, registry
  [kosa22]="2211 2226 2231 2242 2270"   # dns1, haproxy1, master-02, worker-02, siem
  [kosa23]="2312 2327 2332 2343 2380"   # dns2, haproxy2, master-03, worker-03, monitoring
  [kosa24]="2416 2440 2455"             # vault2, worker-plat, cicd
)

# ── 특정 노드 필터 (인자 없으면 전체) ────────────────────────
TARGET="${1:-all}"

destroy_vm() {
  local node="$1"
  local ip="${NODE_IPS[$node]}"
  local vmids="${NODE_VMIDS[$node]}"

  echo ""
  echo "=== [$node] ($ip) 처리 시작 ==="

  for vmid in $vmids; do
    echo "  → VMID $vmid 처리 중..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${SSH_USER}@${ip}" "
      if qm status $vmid > /dev/null 2>&1; then
        qm stop $vmid --skiplock 2>/dev/null || true
        sleep 2
        qm destroy $vmid --purge --destroy-unreferenced-disks 1
        echo '    ✓ VMID $vmid 삭제 완료'
      else
        echo '    - VMID $vmid 존재하지 않음 (스킵)'
      fi
    " || echo "    ✗ VMID $vmid 처리 실패 (노드 연결 오류)"
  done
}

# ── 실행 ─────────────────────────────────────────────────────
echo "프록스목스 VM 강제 삭제 시작..."
echo "대상: ${TARGET}"

for node in "${!NODE_VMIDS[@]}"; do
  if [[ "$TARGET" == "all" || "$TARGET" == "$node" ]]; then
    destroy_vm "$node"
  fi
done

echo ""
echo "완료! 프록스목스 GUI에서 삭제 여부를 확인하세요."
