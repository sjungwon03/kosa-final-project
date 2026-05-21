#!/bin/bash
# =============================================================
# wazuh_all.sh
# Wazuh 전체 설정 통합 실행 스크립트입니다.
# 01 ~ 04 스크립트를 순서대로 일괄 실행합니다.
# siem-01(172.16.30.85)에서 실행해야 합니다.
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================================"
echo " Wazuh 통합 보안 관제 설정 - All In One"
echo " siem-01: 172.16.30.85"
echo "================================================================"
echo ""
echo " 실행 순서:"
echo "   [01] Agent 로그 수집 설정 (SSH 키 배포 + 10대 원격 주입)"
echo "   [02] Manager JSON 정제 설정"
echo "   [03] Indexer 저장 설정"
echo "   [04] Dashboard 데이터 적재"
echo ""
echo " [ERROR] 주의: root 권한 필요, 각 단계별 완료 후 다음 단계 진행"
echo "================================================================"
echo ""

# ---------------------------------------------------------------
# 0. 사전 확인
# ---------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] root 권한으로 실행해주세요: sudo $0"
  exit 1
fi

for SCRIPT in 01_agent_log_collect.sh 02_manager_json_process.sh \
              03_indexer_store.sh 04_dashboard_export.sh; do
  if [[ ! -f "$SCRIPT_DIR/$SCRIPT" ]]; then
    echo "[ERROR] $SCRIPT 파일을 찾을 수 없습니다."
    echo "   스크립트가 같은 디렉토리에 있는지 확인하세요: $SCRIPT_DIR"
    exit 1
  fi
done
echo "   OK... 스크립트 파일 확인 완료"

# ---------------------------------------------------------------
# 단계별 실행 함수
# ---------------------------------------------------------------
run_step() {
  local STEP="$1"
  local SCRIPT="$2"
  local DESC="$3"

  echo ""
  echo "================================================================"
  echo " [$STEP/4] $DESC"
  echo "================================================================"

  if bash "$SCRIPT_DIR/$SCRIPT"; then
    echo ""
    echo "   OK... [$STEP/4] $DESC 완료"
  else
    echo ""
    echo "  [ERROR] [$STEP/4] $DESC 실패"
    echo "   $SCRIPT 를 단독으로 실행해 오류를 확인하세요."
    echo "   sudo bash $SCRIPT_DIR/$SCRIPT"
    exit 1
  fi

  # 단계 간 대기
  if [[ "$STEP" -lt 4 ]]; then
    echo ""
    echo "  다음 단계까지 5초 대기..."
    sleep 5
  fi
}

# ---------------------------------------------------------------
# 실행 모드 선택
# ---------------------------------------------------------------
echo "실행 모드를 선택하세요:"
echo "  1) 전체 자동 실행 (01 → 02 → 03 → 04)"
echo "  2) 단계 선택 실행"
echo ""
read -rp "선택 (1/2): " MODE

case "$MODE" in
  1)
    run_step 1 "01_agent_log_collect.sh"   "Agent 로그 수집 설정"
    run_step 2 "02_manager_json_process.sh" "Manager JSON 정제 설정"
    run_step 3 "03_indexer_store.sh"        "Indexer 저장 설정"
    run_step 4 "04_dashboard_export.sh"     "Dashboard 데이터 적재"
    ;;
  2)
    echo ""
    echo "실행할 단계를 선택하세요 (복수 입력 가능, 예: 1 3):"
    echo "  1) Agent 로그 수집 설정"
    echo "  2) Manager JSON 정제 설정"
    echo "  3) Indexer 저장 설정"
    echo "  4) Dashboard 데이터 적재"
    echo ""
    read -rp "선택 (예: 1 2 3 4): " -a STEPS

    for STEP in "${STEPS[@]}"; do
      case "$STEP" in
        1) run_step 1 "01_agent_log_collect.sh"    "Agent 로그 수집 설정" ;;
        2) run_step 2 "02_manager_json_process.sh"  "Manager JSON 정제 설정" ;;
        3) run_step 3 "03_indexer_store.sh"         "Indexer 저장 설정" ;;
        4) run_step 4 "04_dashboard_export.sh"      "Dashboard 데이터 적재" ;;
        *) echo "  [ERROR] 올바르지 않은 단계 번호: $STEP" ;;
      esac
    done
    ;;
  *)
    echo "[ERROR] 올바른 번호를 입력하세요 (1/2)"
    exit 1
    ;;
esac

# ---------------------------------------------------------------
# 완료 요약
# ---------------------------------------------------------------
echo ""
echo "================================================================"
echo "   OK... Wazuh 전체 설정 완료"
echo ""
echo " 최종 확인:"
echo "   Agent 연결 상태  : sudo /var/ossec/bin/agent_control -l"
echo "   Manager 상태     : systemctl status wazuh-manager"
echo "   Indexer 인덱스   : curl -k -u admin:admin https://172.16.30.85:9200/_cat/indices/wazuh-alerts-*?v"
echo "   Dashboard 접속   : https://172.16.30.85"
echo "================================================================"
