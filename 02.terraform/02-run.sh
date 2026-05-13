#!/bin/bash

# Terraform 환경별 프로비저닝 랩퍼 스크립트
# 실행: 컨트롤 노드 전용
#
# [2026-05-13] 최초 작성

set -euo pipefail

trap 'echo "[$(date +%F\ %T)] failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <ENV> <ACTION> <ROLE> [TARGET_VM]"
  echo "Example:"
  echo "  $0 test plan dns         # test 환경 dns 배포 플랜 확인"
  echo "  $0 test apply haproxy    # test 환경 haproxy 배포"
  echo "  $0 prod destroy all      # prod 환경 전체 삭제"
  echo "  $0 test apply all dns1   # test 환경 dns1 개별 배포"
  exit 1
fi

ENV=$1
ACTION=$2
ROLE=$3
TARGET_VM=${4:-}

if [[ "$ENV" != "test" && "$ENV" != "prod" ]]; then
  echo "ERROR: ENV must be 'test' or 'prod'"
  exit 1
fi

TARGET_DIR="env/${ENV}"

# 스크립트 위치 기준으로 이동 (풀 경로 실행 시에도 동작)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: directory not found: $TARGET_DIR"
  exit 1
fi

cd "$TARGET_DIR"

# 모듈 초기화 (이미 완료된 경우 무시됨)
terraform init -input=false > /dev/null || { echo "ERROR: terraform init failed"; exit 1; }

VAR_FILE="tfvars/${ROLE}.tfvars"
if [ ! -f "$VAR_FILE" ]; then
  echo "ERROR: tfvars file not found: $VAR_FILE"
  exit 1
fi

CMD="terraform $ACTION -var-file=$VAR_FILE -parallelism=1"

if [ -n "$TARGET_VM" ]; then
  CMD="$CMD -target='module.vms.proxmox_virtual_environment_vm.ubuntu[\"$TARGET_VM\"]'"
fi

echo "[$(date '+%F %T')] start terraform ${ACTION} for ${ROLE} in ${ENV}"
echo "[$(date '+%F %T')] execute command: ${CMD}"

eval "${CMD}"

echo "[$(date '+%F %T')] done"
