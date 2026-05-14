#!/bin/bash
# ansible-run.sh — 플레이북 실행자 추적 래퍼
# 사용법: ./ansible-run.sh playbooks/k8s.yml [-i inventories/test/hosts]
#
# 실행 시 ansible.log에 아래 형식으로 자동 기록됨:
#   [2026-05-14 13:00:00] USER=control PLAYBOOK=playbooks/k8s.yml

set -euo pipefail

ANSIBLE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${ANSIBLE_DIR}/ansible.log"
PLAYBOOK="${1:?사용법: $0 <playbook> [추가 옵션]}"
shift

# 실행자 정보 로그 기록
{
  echo ""
  echo "================================================================"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXECUTED BY: $(whoami)@$(hostname)"
  echo "  PLAYBOOK : ${PLAYBOOK}"
  echo "  ARGS     : $*"
  echo "================================================================"
} >> "${LOG_FILE}"

# 플레이북 실행
ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  ansible-playbook "${PLAYBOOK}" "$@"
