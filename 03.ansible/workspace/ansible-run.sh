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
# DEPLOYER 환경변수가 없으면 OS 계정명으로 대체
# TODO: 배포 실행자 추적 — 현재는 컨트롤 노드 계정(control)만 식별됨.
#       Phase 3에서 Gitea Actions 연동 시 DEPLOYER=$GITEA_ACTOR 자동 주입 예정.
DEPLOYER="${DEPLOYER:-$(whoami)}"

{
  echo ""
  echo "================================================================"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXECUTED BY: ${DEPLOYER}@$(hostname)"
  echo "  PLAYBOOK : ${PLAYBOOK}"
  echo "  ARGS     : $*"
  echo "================================================================"
} >> "${LOG_FILE}"

# 플레이북 실행
ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  ansible-playbook "${PLAYBOOK}" "$@"
