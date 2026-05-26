#!/bin/bash

# Proxmox 호스트에서 컨트롤 노드 VM 생성 (VMID 9007 클론)
# 실행: root 전용 (Proxmox 호스트에서)
#
# [2026-05-12] 최초 작성
# [2026-05-12] firewall=1 제거: pfSense가 앞단 방화벽 담당, VM 레벨 방화벽 불필요
# [2026-05-12] set -euo pipefail 주석 추가
# [2026-05-12] ciname으로 호스트명 설정, cicustom으로 cloud-init 완료 후 자동 종료
# [2026-05-12] runcmd: Terraform/Ansible/etcd/etcdkeeper 설치, control 계정만 실행 가능하도록 권한 설정
# [2026-05-12] cicustom qm set 분리: ipconfig0과 cicustom 동시 설정 시 Proxmox가 ipconfig0 무시하는 문제 수정
# [2026-05-12] power_state 주석 처리: 검증 완료 후 필요 시 활성화
# [2026-05-12] ipconfig0/cicustom/ciuser 각각 별도 qm set으로 분리, onboot=1 추가, ciname 제거
# [2026-05-12] etcd GitHub 바이너리 설치로 변경, runcmd 멀티라인 블록으로 변수 유지, groupadd control 추가
# [2026-05-12] etcdkeeper 제거
# [2026-05-12] 버전 고정: terraform=1.15.2, etcd=v3.6.11 / serial0 제거 및 vga=std 복원
# [2026-05-12] cicustom user= → vendor=: user=는 --ciuser/--cipassword를 덮어써 control 계정 미생성 문제 수정
# [2026-05-12] keys/*.pub 수집 후 --sshkeys로 주입: 팀원 공개키 일괄 등록
# [2026-05-12] 버전 변수 상단 분리 (TERRAFORM_VER, ETCD_VER), ssh_pwauth: true 추가
# [2026-05-12] qm destroy 후 Ceph RBD 잔여 이미지 강제 정리 추가
# [2026-05-12] cloud-init 완료 대기 루프 추가 (marker 파일 확인, 최대 10분)

# -e: 명령어 실패 시 즉시 종료 / -u: 미선언 변수 사용 시 오류 / -o pipefail: 파이프 중간 실패도 오류 처리
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ENV_FILE="${SCRIPT_DIR}/.env"

[[ -f "${ENV_FILE}" ]] || { echo "ERROR: ${ENV_FILE} not found. cp .env.example .env 후 수정"; exit 1; }
# shellcheck source=/dev/null
source "${ENV_FILE}"

[[ $EUID -ne 0 ]] && { echo "run as root"; exit 1; }

LOG_FILE="/var/log/create-control-node.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "[$(date '+%F %T')] start"

trap 'echo "[$(date +%F\ %T)] failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

# TODO: 버전 존재 여부 확인 필요 — apt-cache madison terraform (동일 OS에서 실행)
TERRAFORM_VER="1.15.2-1"
ETCD_VER="v3.6.11"

SNIPPET_DIR="/var/lib/vz/snippets"
SNIPPET_FILE="${SNIPPET_DIR}/control-node-userdata.yaml"
KEYS_DIR="${SCRIPT_DIR}/workspace/keys"
SSH_KEYS_FILE="$(mktemp)"
trap 'rm -f "${SSH_KEYS_FILE}"' EXIT

# keys/*.pub 수집
if ls "${KEYS_DIR}"/*.pub &>/dev/null; then
  cat "${KEYS_DIR}"/*.pub > "${SSH_KEYS_FILE}"
  echo "[INFO] SSH keys: $(wc -l < "${SSH_KEYS_FILE}") key(s) found"
else
  echo "[WARN] ${KEYS_DIR}/*.pub 없음 — SSH 키 없이 진행 (비밀번호 인증만 가능)"
fi

# 기존 VM 정리
if qm status "${CONTROL_VMID}" &>/dev/null; then
  echo "VMID ${CONTROL_VMID} exists, purging..."
  qm stop "${CONTROL_VMID}" --skiplock 2>/dev/null || true
  sleep 3
  qm destroy "${CONTROL_VMID}" --purge
fi

# Ceph RBD 잔여 이미지 정리 (qm destroy --purge가 누락할 수 있음)
for img in "vm-${CONTROL_VMID}-disk-0" "vm-${CONTROL_VMID}-cloudinit"; do
  if rbd ls "${STORAGE_POOL}" 2>/dev/null | grep -qx "${img}"; then
    echo "Removing orphaned RBD image: ${STORAGE_POOL}/${img}"
    rbd rm "${STORAGE_POOL}/${img}"
  fi
done

# cicustom 스니펫 생성 (호스트명 설정, cloud-init 완료 후 자동 종료)
pvesm set local --content vztmpl,iso,snippets
mkdir -p "${SNIPPET_DIR}"
cat > "${SNIPPET_FILE}" <<EOF
#cloud-config
ssh_pwauth: true
write_files:
  - path: /etc/ssh/sshd_config.d/10-password-auth.conf
    content: |
      PasswordAuthentication yes
      KbdInteractiveAuthentication yes
runcmd:
  - systemctl enable --now ssh
  # HashiCorp APT 저장소 추가 후 Terraform, Ansible 설치
  - wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  - echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com noble main" | tee /etc/apt/sources.list.d/hashicorp.list
  - apt-get update && apt-get install -y terraform=${TERRAFORM_VER} ansible
  # etcd (Ubuntu 24.04 기본 저장소 미포함 → GitHub 바이너리)
  - |
    curl -L "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz" -o /tmp/etcd.tar.gz
    tar -xzf /tmp/etcd.tar.gz -C /tmp/
    mv /tmp/etcd-${ETCD_VER}-linux-amd64/etcd /usr/local/bin/
    mv /tmp/etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/
    rm -rf /tmp/etcd.tar.gz /tmp/etcd-${ETCD_VER}-linux-amd64
  # control 그룹 생성 및 Terraform/Ansible 실행 권한 설정
  - groupadd -f control
  - chown root:control /usr/bin/terraform && chmod 750 /usr/bin/terraform
  - find /usr/bin -name 'ansible*' -exec chown root:control {} \; -exec chmod 750 {} \;
  - echo "[cloud-init] done" | tee /var/log/cloud-init-done.marker
# TODO: 검증 완료 후 자동 종료 필요 시 아래 주석 해제
# power_state:
#   mode: poweroff
#   timeout: 120
#   condition: true
EOF

# 풀 클론
echo "[$(date '+%F %T')] cloning ${TEMPLATE_VMID} → ${CONTROL_VMID}..."
qm clone "${TEMPLATE_VMID}" "${CONTROL_VMID}" \
  --name "${CONTROL_NAME}" \
  --full \
  --storage "${STORAGE_POOL}"

# 리소스 설정
qm set "${CONTROL_VMID}" \
  --cores "${CORES}" \
  --memory "${MEMORY}"

# 네트워크 설정
qm set "${CONTROL_VMID}" \
  --net0 "virtio,bridge=${BRIDGE},tag=${VLAN}"

# cloud-init 설정: 옵션별 분리 (같은 qm set에 넣으면 Proxmox가 일부 옵션을 무시하는 경우 있음)
# TODO: Vault 구성 시 cipassword를 vault에서 주입
qm set "${CONTROL_VMID}" \
  --ciuser "${CIUSER}" \
  --cipassword "${CIPASSWORD}" \
  --nameserver "8.8.8.8 1.1.1.1"

# SSH 공개키 주입 (keys/*.pub)
if [[ -s "${SSH_KEYS_FILE}" ]]; then
  qm set "${CONTROL_VMID}" --sshkeys "${SSH_KEYS_FILE}"
fi

qm set "${CONTROL_VMID}" \
  --ipconfig0 "ip=${CONTROL_IP}/${NETMASK},gw=${CONTROL_GW}"

qm set "${CONTROL_VMID}" \
  --cicustom "vendor=local:snippets/$(basename "${SNIPPET_FILE}")"

# 엔트로피 소스 (SSH 호스트 키 생성 블로킹 방지)
qm set "${CONTROL_VMID}" --rng0 source=/dev/urandom

# Proxmox 재부팅 시 자동 시작
qm set "${CONTROL_VMID}" --onboot 1

# serial0 제거 및 vga 복원 (Packer 템플릿이 serial0으로 설정 → 웹 콘솔 로그인 프롬프트 미출력)
qm set "${CONTROL_VMID}" --vga std --delete serial0

# VM 시작
echo "[$(date '+%F %T')] starting VM..."
qm start "${CONTROL_VMID}"

# cloud-init 완료 대기 (marker 파일 확인, 최대 10분)
echo "[$(date '+%F %T')] waiting for cloud-init to finish (max 10min)..."
for i in {1..60}; do
  if qm agent "${CONTROL_VMID}" exec -- cat /var/log/cloud-init-done.marker &>/dev/null; then
    echo "[$(date '+%F %T')] cloud-init finished."
    break
  fi
  echo "  waiting... (${i}/60)"
  sleep 10
done

echo "[$(date '+%F %T')] done"
