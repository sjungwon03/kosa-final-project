#!/bin/bash

# Terraform 환경별 프로비저닝 랩퍼 스크립트
# 실행: 컨트롤 노드 전용
#
# [2026-05-13] 최초 작성
# [2026-05-18] terraform init -reconfigure 추가 (backend 캐시 불일치 오류 대응)
# [2026-05-18] -backend-config로 key 동적 주입 (서비스별 state 분리)
# [2026-05-18] key 단일 파일로 복원 (prod/terraform.tfstate) — 역할별 분리 시 빈 state 참조 문제 발생

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

# 모듈 초기화 (-reconfigure: backend 캐시 불일치 시에도 state 보존하며 재초기화)
terraform init -reconfigure -backend-config="key=${ENV}/terraform.tfstate" -input=false > /dev/null || { echo "ERROR: terraform init failed"; exit 1; }

VAR_FILE="tfvars/${ROLE}.tfvars"
if [ ! -f "$VAR_FILE" ]; then
  echo "ERROR: tfvars file not found: $VAR_FILE"
  exit 1
fi

# TODO: parallelism=1은 Ceph RBD 동시 클론 시 OSD 락 충돌 방지를 위한 값
#       안정성 확인 후 3으로 올리면 전체 배포 시간 약 1/3 단축 가능 (5 이상은 OSD 부하로 역효과)
CMD="terraform $ACTION -var-file=$VAR_FILE -parallelism=1"

if [ -n "$TARGET_VM" ]; then
  CMD="$CMD -target='module.vms.proxmox_virtual_environment_vm.ubuntu[\"$TARGET_VM\"]'"
fi

START_TIME=$(date +%s)
echo "[$(date '+%F %T')] start terraform ${ACTION} for ${ROLE} in ${ENV}"
echo "[$(date '+%F %T')] execute command: ${CMD}"

eval "${CMD}"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo "[$(date '+%F %T')] done in ${MINUTES}m ${SECONDS}s"
