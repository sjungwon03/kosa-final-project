#!/bin/bash

# 유령 VM 강제 제거
# 실행: root 전용
# 사용법: bash force-destroy-vm.sh <VMID>
set -euo pipefail

VMID="${1:?Usage: $0 <VMID>}"

[[ $EUID -ne 0 ]] && { echo "run as root"; exit 1; }

trap 'echo "failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

# qm destroy 시도
if qm status "${VMID}" &>/dev/null; then
  echo "VM ${VMID} found, destroying..."
  qm destroy "${VMID}" --purge 2>/dev/null && echo "done" && exit 0
fi

# conf 파일 전 노드 강제 제거
echo "removing ghost conf files for VMID ${VMID}..."
for conf in /etc/pve/nodes/*/qemu-server/${VMID}.conf; do
  [[ -f "${conf}" ]] && rm -f "${conf}" && echo "removed: ${conf}"
done

# Ceph 볼륨 정리 (storage.cfg에서 rbd pool 이름 자동 추출)
echo "cleaning up Ceph volumes..."
while read -r rbd_pool; do
  for vol in $(rbd ls "${rbd_pool}" 2>/dev/null | grep "^vm-${VMID}-"); do
    rbd rm "${rbd_pool}/${vol}" && echo "removed rbd: ${rbd_pool}/${vol}"
  done
done < <(grep -A10 '^rbd:' /etc/pve/storage.cfg | awk '/^\s*pool\s/{print $2}')

echo "done: VMID ${VMID} cleaned"
