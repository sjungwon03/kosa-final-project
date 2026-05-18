#!/bin/bash

# 컨트롤 노드 배포 스크립트
#
# [2026-05-13] 최초 작성
# [2026-05-16] scp -> rsync 변경 (숨김 파일 누락 방지 및 전송 속도 최적화)
# [2026-05-18] ~/workspace/{terraform,ansible} 구조로 증분 동기화 (terraform state 보존)
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

echo "[2/4] Terraform 파일 동기화 (state 및 중요 자산 보존)..."
# --delete 옵션을 적용하되 원격지의 state 파일, 로그 및 키 파일이 유실되는 대참사를 방지하기 위해 정교하게 exclude 처리
rsync -avz --delete \
  -e "ssh -o ControlPath=${CONTROL_SOCKET}" \
  --exclude=".git/" \
  --exclude=".terraform/" \
  --exclude=".terraform.lock.hcl" \
  --exclude="**/.terraform/" \
  --exclude="**/.terraform.lock.hcl" \
  --exclude="**/terraform.tfstate" \
  --exclude="**/terraform.tfstate.*" \
  --exclude="**/*.tfstate" \
  --exclude="**/*.tfstate.*" \
  --exclude="**/*.log" \
  --exclude="**/*.key" \
  --exclude="**/*.pub" \
  "${PROJECT_ROOT}/02.terraform/" "${CONTROL_HOST}:${REMOTE_WORKSPACE}/terraform/"

echo "[3/4] Ansible 파일 동기화 (원격 자산 보호)..."
# --delete 옵션을 적용하되 원격에 축적되는 플레이북 실행 로그(*.log) 및 개별 키 파일 등을 안전하게 배제
rsync -avz --delete \
  -e "ssh -o ControlPath=${CONTROL_SOCKET}" \
  --exclude=".git/" \
  --exclude="**/*.log" \
  --exclude="**/*.key" \
  --exclude="**/*.pub" \
  --exclude="**/keys/" \
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
