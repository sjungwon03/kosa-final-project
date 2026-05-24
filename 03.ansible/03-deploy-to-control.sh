#!/bin/bash

# 컨트롤 노드 배포 스크립트
#
# [2026-05-13] 최초 작성
# [2026-05-16] scp -> rsync 변경 (숨김 파일 누락 방지 및 전송 속도 최적화)
# [2026-05-18] ~/workspace/{terraform,ansible} 구조로 증분 동기화 (terraform state 보존)
# [2026-05-18] k8s 관련 동기화 제외 패턴 제거 (지속적 하드웨어 및 설정 수정 반영)
# [2026-05-18] terraform state MinIO 백엔드 이관 완료로 tfstate exclude 제거
# [2026-05-18] .terraform.lock.hcl exclude 제거 (소스 파일로 동기화 대상에 포함)
# [2026-05-18] .tfvars 변수 파일들은 지속적인 하드웨어 사양 및 설정 수정 사항을 즉각 반영하기 위해 동기화에 포함함
#
# 실행: 로컬(노트북)에서 실행
# 사용법: bash 03.ansible/03-deploy-to-control.sh
# 예시:  bash 03.ansible/03-deploy-to-control.sh

set -euo pipefail

CONTROL_HOST="control@172.16.30.7"
REMOTE_WORKSPACE="~/workspace"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# SSH 연결 재사용 (최초 1회만 비밀번호 입력)
CONTROL_SOCKET="/tmp/deploy_control_${USER}.sock"
SSH_OPTS="-o ControlMaster=auto -o ControlPath=${CONTROL_SOCKET} -o ControlPersist=60"

echo "[0/4] SSH 연결 초기화 (비밀번호 1회 입력)..."
ssh $SSH_OPTS "$CONTROL_HOST" "echo connected"

echo "[1/4] 컨트롤 노드 디렉토리 구조 확인..."
ssh $SSH_OPTS "$CONTROL_HOST" "
  mkdir -p ${REMOTE_WORKSPACE}/terraform ${REMOTE_WORKSPACE}/ansible
"

echo "[2/4] Terraform 파일 동기화 (중요 자산 보존)..."
# --delete 옵션 적용 시 원격 credentials·로그·키 파일 유실 방지를 위해 exclude 처리
# state는 MinIO 백엔드에서 관리하므로 tfstate exclude 불필요
rsync -avz --delete \
  -e "ssh -o ControlPath=${CONTROL_SOCKET}" \
  --exclude=".git/" \
  --exclude=".terraform/" \
  --exclude="**/.terraform/" \
  --exclude="**/credentials.auto.tfvars" \
  --exclude="**/*.log" \
  --exclude="**/*.key" \
  "${PROJECT_ROOT}/02.terraform/" "${CONTROL_HOST}:${REMOTE_WORKSPACE}/terraform/"

echo "[3/4] Ansible 파일 동기화 (원격 자산 보호)..."
# --delete 옵션 적용 시 원격 로그·키 파일 보호
rsync -avz --delete \
  -e "ssh -o ControlPath=${CONTROL_SOCKET}" \
  --exclude=".git/" \
  --exclude="**/*.log" \
  --exclude="**/*.key" \
  "${SCRIPT_DIR}/workspace/" "${CONTROL_HOST}:${REMOTE_WORKSPACE}/ansible/"

echo "[4/4] 실행 권한 부여..."
ssh $SSH_OPTS "$CONTROL_HOST" "chmod +x ${REMOTE_WORKSPACE}/terraform/02-run.sh"

# 소켓 정리
ssh -O exit -o ControlPath="${CONTROL_SOCKET}" "$CONTROL_HOST" 2>/dev/null || true

echo ""
echo "배포 완료!"
echo "컨트롤 노드 경로: ~/workspace/"
echo "  ├── terraform/"
echo "  └── ansible/"
