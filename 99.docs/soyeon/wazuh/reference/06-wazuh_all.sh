#!/bin/bash
# =============================================================
# 05-active_response.sh
# Wazuh Active Response 설정 스크립트
# siem-01(172.16.30.85)에서 실행
#
# 동작 흐름:
#   Manager 룰 매칭 (level 임계값 초과)
#   → Manager가 해당 Agent에 명령 전달
#   → Agent가 자기 서버에서 차단 스크립트 실행
#   → 설정된 timeout 후 자동 해제
#
# 차단 대상 룰:
#   [공통]    SSH 브루트포스        (Wazuh 기본 룰 5720)
#   [공통]    SSH 인증 반복 실패    (Wazuh 기본 룰 5763)
#   [pfSense] 포트스캔 의심        (커스텀 룰 100201)
#   [pfSense] OpenVPN 브루트포스   (커스텀 룰 100211)
# =============================================================

set -euo pipefail

# sudo 인증 캐시 (이후 sudo 명령 비번 불필요)
sudo -v

OSSEC_CONF="/var/ossec/etc/ossec.conf"
OSSEC_CONF_BAK="/var/ossec/etc/ossec.conf.bak.$(date +%Y%m%d_%H%M%S)"
AR_BIN_DIR="/var/ossec/active-response/bin"

backup_conf() {
  echo "" && echo "  ossec.conf 백업 중..."
  sudo cp "$OSSEC_CONF" "$OSSEC_CONF_BAK"
  echo "  OK... 백업 완료: $OSSEC_CONF_BAK" && echo ""
}

# =============================================================
# [옵션 A] 사전 환경 확인
# =============================================================
check_environment() {
  echo "" && echo "[옵션 A] 사전 환경 확인" && echo ""

  echo "  [1] Active Response 기본 스크립트 확인 ($AR_BIN_DIR)"
  for SCRIPT in "firewall-drop" "host-deny" "disable-account"; do
    echo -n "      $SCRIPT ... "
    sudo test -f "${AR_BIN_DIR}/${SCRIPT}" && echo "OK" || echo "MISSING"
  done
  echo ""

  echo "  [2] 현재 ossec.conf active-response 설정"
  if sudo grep -q "<active-response>" "$OSSEC_CONF"; then
    sudo grep -A6 "<active-response>" "$OSSEC_CONF"
  else
    echo "  [INFO] active-response 블록 없음 -> 옵션 B 실행 필요"
  fi
  echo ""

  echo -n "  [3] wazuh-manager 서비스 상태... "
  if systemctl is-active --quiet wazuh-manager; then
    echo "OK (실행 중)"
  else
    echo "FAIL (중지 상태)"
    echo "       sudo systemctl start wazuh-manager"
  fi
  echo ""
}

# =============================================================
# [옵션 B] Active Response 설정 주입
# =============================================================
configure_active_response() {
  echo "" && echo "[옵션 B] Active Response 설정 주입" && echo ""

  if sudo grep -q "<active-response>" "$OSSEC_CONF"; then
    echo "  [INFO] 기존 active-response 블록 감지됨"
    read -rp "  덮어쓰시겠습니까? (y/N): " OVERWRITE
    if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
      echo "  취소됨" && return
    fi
    sudo sed -i '/<active-response>/,/<\/active-response>/d' "$OSSEC_CONF"
    echo "  OK... 기존 블록 제거 완료"
  fi

  backup_conf

  TMP_AR=$(mktemp)
  cat > "$TMP_AR" << 'AR_CONF'

  <!-- SSH 브루트포스 탐지 시 공격 IP 차단 (해당 서버만 / 600초) -->
  <active-response>
    <command>firewall-drop</command>
    <location>local</location>
    <rules_id>5720</rules_id>
    <timeout>600</timeout>
  </active-response>

  <!-- SSH 인증 반복 실패 시 공격 IP 차단 (해당 서버만 / 600초) -->
  <active-response>
    <command>firewall-drop</command>
    <location>local</location>
    <rules_id>5763</rules_id>
    <timeout>600</timeout>
  </active-response>

  <!-- pfSense 포트스캔 탐지 시 공격 IP 전체 차단 전파 (1800초) -->
  <active-response>
    <command>firewall-drop</command>
    <location>all</location>
    <rules_id>100201</rules_id>
    <timeout>1800</timeout>
  </active-response>

  <!-- OpenVPN 브루트포스 탐지 시 공격 IP 전체 차단 전파 (1800초) -->
  <active-response>
    <command>firewall-drop</command>
    <location>all</location>
    <rules_id>100211</rules_id>
    <timeout>1800</timeout>
  </active-response>

AR_CONF

  sudo python3 -c "
content = open('$OSSEC_CONF').read()
insert = open('$TMP_AR').read()
open('$OSSEC_CONF', 'w').write(content.replace('</ossec_config>', insert + '</ossec_config>'))
"
  rm -f "$TMP_AR"

  echo "  OK... Active Response 설정 주입 완료"
  echo ""
  echo "  [적용된 차단 정책]"
  echo "  ┌─────────────────────────┬──────────────┬──────────┬────────┐"
  echo "  │ 탐지 조건               │ 차단 범위    │ 해제     │ 룰 ID  │"
  echo "  ├─────────────────────────┼──────────────┼──────────┼────────┤"
  echo "  │ SSH 브루트포스          │ 해당 서버만  │ 10분 후  │  5720  │"
  echo "  │ SSH 인증 반복 실패      │ 해당 서버만  │ 10분 후  │  5763  │"
  echo "  │ pfSense 포트스캔        │ 전체 10대    │ 30분 후  │ 100201 │"
  echo "  │ OpenVPN 브루트포스      │ 전체 10대    │ 30분 후  │ 100211 │"
  echo "  └─────────────────────────┴──────────────┴──────────┴────────┘"
  echo ""
  echo "  [다음 단계] wazuh-manager 재시작 필요:"
  echo "  sudo systemctl restart wazuh-manager"
  echo ""
}

# =============================================================
# [옵션 C] Active Response 검증
# =============================================================
verify_active_response() {
  echo "" && echo "[옵션 C] Active Response 검증" && echo ""

  echo "  [1] ossec.conf 문법 검증"
  ANALYSISD_ERR=$(sudo /var/ossec/bin/wazuh-analysisd -t 2>&1 | grep -i "error" || true)
  if [[ -z "$ANALYSISD_ERR" ]]; then
    echo "  OK... 문법 검증 통과"
  else
    echo "  [WARN] 문법 오류 감지:"
    echo "$ANALYSISD_ERR"
  fi
  echo ""

  echo "  [2] Active Response 설정 확인"
  sudo grep -A5 "<active-response>" "$OSSEC_CONF" || \
    echo "  [WARN] active-response 블록 없음"
  echo ""
}

# =============================================================
# [옵션 D] 차단 이력 확인
# =============================================================
check_block_status() {
  echo "" && echo "[옵션 D] 차단 이력 확인" && echo ""

  echo "  [1] Active Response 실행 로그 (최근 20건)"
  if [[ -f /var/ossec/logs/active-responses.log ]]; then
    sudo tail -n 20 /var/ossec/logs/active-responses.log
  else
    echo "  [INFO] 아직 Active Response 실행 이력 없음"
  fi
  echo ""

  echo "  [2] Manager 서버 현재 차단 IP (iptables)"
  sudo iptables -L INPUT -n | grep "DROP" | grep -v "Chain\|target" || \
    echo "  [INFO] 현재 차단된 IP 없음"
  echo ""

  echo "  [참고 명령어]"
  echo "  sudo tail -f /var/ossec/logs/active-responses.log"
  echo "  sudo iptables -D INPUT -s <IP> -j DROP"
  echo "  sudo iptables -L INPUT -n --line-numbers"
  echo ""
}

# =============================================================
# 메인 실행
# =============================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
echo "================================================================"
echo " Wazuh Active Response 설정"
echo " Manager: 172.16.30.85"
echo ""
echo " 탐지 즉시 자동 차단 - 별도 프로그램 불필요 (Wazuh 내장)"
echo " 차단 방식: Manager -> Agent -> iptables firewall-drop"
echo "================================================================"
echo ""
echo "  1) 사전 환경 확인    (AR 스크립트 현재 설정 상태)"
echo "  2) AR 설정 주입      (SSH 포트스캔 OpenVPN 자동 차단)"
echo "  3) 검증              (문법검증 설정확인)"
echo "  4) 차단 이력 확인    (실행 로그 현재 차단 IP)"
echo "  5) 전체 실행         (1 -> 2 -> 3)"
echo ""
read -rp "선택 (1/2/3/4/5): " CHOICE

case "$CHOICE" in
  1) check_environment ;;
  2) configure_active_response ;;
  3) verify_active_response ;;
  4) check_block_status ;;
  5) check_environment && configure_active_response && verify_active_response ;;
  *) echo "[ERROR] 올바른 번호를 입력하세요 (1/2/3/4/5)"; exit 1 ;;
esac

echo ""
echo "================================================================"
echo "   OK... 05-active_response.sh 완료"
echo "================================================================"
fi
