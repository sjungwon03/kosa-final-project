#!/bin/bash

# Proxmox kosa22 노드에서 Ubuntu 24.04 VM 생성
# 실행: root 전용
#
# [2026-05-11] 최초 작성
# [2026-05-11] Ceph 폴백(local-lvm), 이미지 재사용 로직 추가
# [2026-05-11] cloud-init: ciuser/cipassword 추가, net0 vmbr0 static 192.168.34.2/24
# [2026-05-11] 스펙 반영: cpu=host, sockets=1, numa=0, iothread=1, tag=20, 10G resize
# [2026-05-11] serial 포트 제거, 이미지 재사용 (ISO 스토리지 유지)
# [2026-05-11] virt-customize 네트워크 없음 확인 → --firstboot-command로 첫 부팅 시 apt-get install qemu-guest-agent
# [2026-05-11] SSH 패스워드 인증 활성화 (Ubuntu cloud image 기본값 no), 타임존 Asia/Seoul
# [2026-05-11] VM 부팅 후 qemu-guest-agent 대기(최대 5분) → 종료 → 템플릿 변환 자동화
# [2026-05-11] apt 실행 전 ping 8.8.8.8 인터넷 연결 확인, 타임스탬프 로그(/var/log/create-ubuntu-template.log)
# [2026-05-11] firstboot-command에 curl 설치 추가 (apt-get 동작 검증용)
# [2026-05-11] cloudinit 드라이브 생성 전 기존 Ceph 볼륨 정리 (rbd already exists 방지)
# [2026-05-11] firstboot-command 로그 추가 (/var/log/firstboot.log, 타임스탬프)
# [2026-05-11] qemu-agent 대기 루프에 경과 시간 출력 및 VM 중단 시 즉시 실패 처리
# [2026-05-11] firstboot-command에 apt-get upgrade 추가 (update 후 upgrade 후 install)
# [2026-05-11] serial0 socket 추가 (qm terminal 접속용)
# [2026-05-11] sshd_config.d/99-password-auth.conf 추가 (60-cloudimg-settings.conf override)
# [2026-05-12] 99-password-auth.conf → 60-cloudimg-settings.conf 직접 수정으로 변경
#              이유: sshd는 첫 번째 값 우선, 60이 99보다 먼저라 99가 무시됨 → SSH 인증 실패
# [2026-05-11] LIBGUESTFS_BACKEND=direct 추가, vmbr0 고정, qm terminal root 자동 로그인 적용
# [2026-05-11] Packer 연동을 위한 cloud-init clean 및 machine-id 초기화 로직 추가
# [2026-05-12] VMID를 인자로 받도록 변경 (기본값 9000, 예: bash script.sh 9002)
# [2026-05-12] snapd 제거 재추가 (Ubuntu cloud image 기본 포함, 부팅 지연 원인)
# [2026-05-12] qemu-agent 대기 타임아웃 5분→10분 (apt upgrade 포함, 베이스 템플릿 기준 최대)
# [2026-05-12] --firstboot-command 제거, cicustom으로 교체
#              이유: Ubuntu 22.04 cloud image에서 virt-customize firstboot 서비스 미실행
#                   cloud-init이 먼저 실행되어 firstboot.service가 동작하지 않음
#                   cicustom(Proxmox user-data)은 cloud-init이 직접 처리하므로 신뢰 가능
# [2026-05-12] SSH 패스워드 인증을 virt-customize --run-command에서 cicustom ssh_pwauth로 이동
# [2026-05-12] Ubuntu 22.04 → 24.04 (Noble) 로 변경
# [2026-05-12] cicustom package_upgrade 제거: Ubuntu 24.04 noble cloud image에 qemu-guest-agent 기본 포함
#              qemu-agent 대기 타임아웃 10분→15분 (여유분 유지)
# [2026-05-12] snapd purge에 || true 추가 (24.04 noble cloud image에 snapd 없을 수 있음)
#              $TERM → vt100 고정 (virt-customize 게스트 쉘 변수 확장 방지)
# [2026-05-12] qm agent exec 제거: Proxmox에서 인자 전달 불가 (400 too many arguments)
#              cloud-init clean / machine-id 초기화 → Packer SSH 프로비저너로 이동

set -euo pipefail

# libguestfs 환경 변수 (Proxmox 호스트 권한 에러 방지)
export LIBGUESTFS_BACKEND=direct

VMID=${1:-9000}
VM_NAME="ubuntu-2404-base"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_PATH="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"
STORAGE_POOL="rbd-storage"
FALLBACK_POOL="local-lvm"
BRIDGE="vmbr0"
SNIPPET_DIR="/var/lib/vz/snippets"
SNIPPET_FILE="${SNIPPET_DIR}/ubuntu-2404-base-userdata.yaml"

LOG_FILE="/var/log/create-ubuntu-template.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "[$(date '+%F %T')] start"

trap 'echo "[$(date +%F\ %T)] failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

[[ $EUID -ne 0 ]] && { echo "run as root"; exit 1; }

# 스토리지 가용성 체크
if pvesm status | grep -q "^${STORAGE_POOL}"; then
  echo "storage: ${STORAGE_POOL} (Ceph)"
else
  echo "Ceph unavailable, falling back to ${FALLBACK_POOL}"
  STORAGE_POOL="${FALLBACK_POOL}"
fi

# 기존 VM 정리
if qm status "${VMID}" &>/dev/null; then
  echo "VMID ${VMID} exists, purging..."
  qm destroy "${VMID}" --purge
fi

# 이미지 다운로드 및 준비
mkdir -p "$(dirname "${IMAGE_PATH}")"
if [[ -f "${IMAGE_PATH}" && -s "${IMAGE_PATH}" ]]; then
  echo "image exists, skipping download"
else
  echo "downloading image..."
  wget -nv -O "${IMAGE_PATH}" "${IMAGE_URL}"
fi

echo "[$(date '+%F %T')] checking internet connectivity..."
ping -c 3 -W 3 8.8.8.8 > /dev/null 2>&1 || { echo "ERROR: no internet connectivity"; exit 1; }

# libguestfs-tools 확인
dpkg -l libguestfs-tools &>/dev/null || apt-get install -y libguestfs-tools

# 이미지 수정: snapd 제거, ttyS0 자동 로그인 적용 (SSH/패키지는 cicustom에서 처리)
echo "[$(date '+%F %T')] customizing image..."
virt-customize -a "${IMAGE_PATH}" \
  --run-command "apt-get purge -y snapd && apt-get autoremove -y || true" \
  --run-command "mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d/" \
  --run-command "printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin root --noclear %%I vt100\n' > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf" \
  --timezone "Asia/Seoul"

# cicustom 스니펫 생성 (cloud-init이 부팅 시 처리: 패키지 설치, SSH 설정)
echo "[$(date '+%F %T')] creating cicustom snippet..."
pvesm set local --content vztmpl,iso,snippets
mkdir -p "${SNIPPET_DIR}"
cat > "${SNIPPET_FILE}" <<'EOF'
#cloud-config
ssh_pwauth: true
package_update: true
packages:
  - qemu-guest-agent
runcmd:
  - systemctl enable --now qemu-guest-agent
EOF

# VM 생성
echo "[$(date '+%F %T')] creating VM..."
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
  --serial0 socket \
  --vga serial0 \
  --net0 virtio,bridge="${BRIDGE}",tag=20

# 디스크 임포트
qm set "${VMID}" --scsihw virtio-scsi-single \
  --scsi0 "${STORAGE_POOL}:0,import-from=${IMAGE_PATH},discard=on,iothread=1,ssd=1"

# 부가 설정
qm disk resize "${VMID}" scsi0 10G
qm set "${VMID}" --ide2 "${STORAGE_POOL}:cloudinit"
qm set "${VMID}" --ciuser kosa --cipassword kosa1004 --ipconfig0 ip=dhcp
qm set "${VMID}" --cicustom "user=local:snippets/$(basename ${SNIPPET_FILE})"
qm set "${VMID}" --boot c --bootdisk scsi0

# Agent 설치를 위한 초기 부팅
echo "[$(date '+%F %T')] starting VM for firstboot..."
qm start "${VMID}"

echo "[$(date '+%F %T')] waiting for qemu-guest-agent (max 15m)..."
for i in $(seq 1 180); do
  if qm agent "${VMID}" ping &>/dev/null; then
    echo "[$(date '+%F %T')] qemu-guest-agent confirmed"
    break
  fi
  
  qm status "${VMID}" | grep -q "running" || { echo "ERROR: VM stopped unexpectedly"; exit 1; }
  echo "[$(date '+%F %T')] still waiting... ($((i*5))s elapsed)"
  sleep 5
  
  [[ $i -eq 180 ]] && { echo "ERROR: agent timeout"; exit 1; }
done

# 종료 및 템플릿 변환
# cloud-init clean / machine-id 초기화는 Packer SSH 프로비저너에서 처리
echo "[$(date '+%F %T')] shutting down and converting to template..."
qm shutdown "${VMID}"
qm wait "${VMID}"
# cicustom 제거 (템플릿 클론 시 스니펫 경로 의존성 방지)
qm set "${VMID}" --delete cicustom
qm template "${VMID}"

echo "[$(date '+%F %T')] successfully created template: ${VM_NAME} (${VMID})"