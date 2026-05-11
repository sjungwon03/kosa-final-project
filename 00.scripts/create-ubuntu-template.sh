#!/bin/bash

# Proxmox kosa22 노드에서 빈 템플릿 생성
# 실행: root 전용
set -euo pipefail

VMID=9000
VM_NAME="ubuntu-2204-base"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_PATH="/var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img"
STORAGE_POOL="rbd-storage"
FALLBACK_POOL="local-lvm"
BRIDGE="vmbr1"

trap 'echo "failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

[[ $EUID -ne 0 ]] && { echo "run as root"; exit 1; }

if pvesm status | grep -q "^${STORAGE_POOL}"; then
  echo "storage: ${STORAGE_POOL} (Ceph)"
else
  echo "Ceph unavailable, falling back to ${FALLBACK_POOL}"
  STORAGE_POOL="${FALLBACK_POOL}"
fi

if qm status "${VMID}" &>/dev/null; then
  echo "VMID ${VMID} exists, purging..."
  touch "/etc/pve/nodes/$(hostname)/qemu-server/${VMID}.conf"
  qm destroy "${VMID}" --purge
fi

mkdir -p "$(dirname "${IMAGE_PATH}")"
if [[ -f "${IMAGE_PATH}" && -s "${IMAGE_PATH}" ]]; then
  echo "image exists, skipping download"
elif [[ -f "${HOME}/$(basename "${IMAGE_PATH}")" ]]; then
  echo "copying existing image from home..."
  cp "${HOME}/$(basename "${IMAGE_PATH}")" "${IMAGE_PATH}"
else
  echo "downloading image..."
  wget -q --show-progress -O "${IMAGE_PATH}" "${IMAGE_URL}"
fi

qm create "${VMID}" \
  --name "${VM_NAME}" \
  --memory 2048 \
  --cores 2 \
  --sockets 1 \
  --cpu host \
  --numa 0 \
  --machine q35 \
  --ostype l26 \
  --agent 1 \
  --net0 virtio,bridge=${BRIDGE},firewall=1

qm importdisk "${VMID}" "${IMAGE_PATH}" "${STORAGE_POOL}"
DISK_REF=$(qm config "${VMID}" | grep "^unused0:" | cut -d' ' -f2)
[[ -z "${DISK_REF}" ]] && { echo "disk import failed: unused0 not found in VM config"; exit 1; }

# discard/ssd: Ceph rbd_discard_enable_writeback 설정 필요
qm set "${VMID}" --scsihw virtio-scsi-single --scsi0 "${DISK_REF},discard=on,iothread=1,ssd=1"
qm disk resize "${VMID}" scsi0 10G
qm set "${VMID}" --ide2 "${STORAGE_POOL}:cloudinit"
qm set "${VMID}" --boot c --bootdisk scsi0
qm set "${VMID}" --serial0 socket --vga serial0

qm template "${VMID}"
rm -f "${IMAGE_PATH}"

echo "done: ${VM_NAME} (${VMID})"
