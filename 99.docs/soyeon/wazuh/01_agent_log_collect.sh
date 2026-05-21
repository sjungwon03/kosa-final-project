#!/bin/bash
# =============================================================
# 01_agent_log_collect.sh
# Wazuh Agent 로그 수집 설정 스크립트
# siem-01(172.16.30.85)에서 실행 → 19대 Agent 서버에 원격 일괄 주입
# =============================================================

set -euo pipefail

MANAGER_IP="172.16.30.85"
AGENT_USER="ubuntu"

# =============================================================
# Agent 서버 IP 목록 (19대 - VM 대표 IP 기준)
# 복수 IP 보유 서버: k8s-master-01(.30/.31), dns1(.10/.11), monitor-01(.90/.91)
# Agent는 VM당 1개 설치이므로 대표 IP만 사용
# =============================================================
AGENT_IPS=(
  "172.16.30.30"   # k8s-master-01
  "172.16.30.32"   # k8s-master-02
  "172.16.30.33"   # k8s-master-03
  "172.16.30.45"   # k8s-worker-01
  "172.16.30.46"   # k8s-worker-02
  "172.16.30.47"   # k8s-worker-03
  "172.16.30.40"   # k8s-worker-plat
  "172.16.30.10"   # dns1
  "172.16.30.12"   # dns2
  "172.16.30.21"   # vault-01
  "172.16.30.22"   # vault-02
  "172.16.30.23"   # vault-03
  "172.16.20.26"   # haproxy-01
  "172.16.20.27"   # haproxy-02
  "172.16.30.7"    # control
  "172.16.30.70"   # minio-01
  "172.16.30.90"   # monitor-01
  "172.16.30.55"   # cicd-01
  "172.16.30.15"   # nexus-01
)

declare -A SERVER_NAMES=(
  ["172.16.30.30"]="k8s-master-01"
  ["172.16.30.32"]="k8s-master-02"
  ["172.16.30.33"]="k8s-master-03"
  ["172.16.30.45"]="k8s-worker-01"
  ["172.16.30.46"]="k8s-worker-02"
  ["172.16.30.47"]="k8s-worker-03"
  ["172.16.30.40"]="k8s-worker-plat"
  ["172.16.30.10"]="dns1"
  ["172.16.30.12"]="dns2"
  ["172.16.30.21"]="vault-01"
  ["172.16.30.22"]="vault-02"
  ["172.16.30.23"]="vault-03"
  ["172.16.20.26"]="haproxy-01"
  ["172.16.20.27"]="haproxy-02"
  ["172.16.30.7"]="control"
  ["172.16.30.70"]="minio-01"
  ["172.16.30.90"]="monitor-01"
  ["172.16.30.55"]="cicd-01"
  ["172.16.30.15"]="nexus-01"
)

# k8s 노드 (컨테이너 로그 + k8s 설정 FIM 추가)
K8S_IPS=("172.16.30.30" "172.16.30.32" "172.16.30.33"
          "172.16.30.45" "172.16.30.46" "172.16.30.47" "172.16.30.40")
# Vault 노드 (vault.d FIM 추가)
VAULT_IPS=("172.16.30.21" "172.16.30.22" "172.16.30.23")
# HAProxy 노드 (haproxy 설정 FIM 추가)
HAPROXY_IPS=("172.16.20.26" "172.16.20.27")

# =============================================================
# [옵션 A] SSH 키 배포 (최초 1회 - 패스워드 → 키 방식 전환)
# siem-01의 공개키를 19대에 배포, 이후 패스워드 없이 접속 가능
# 필요 패키지: sudo apt install sshpass
# =============================================================
setup_ssh_key() {
  echo ""
  echo "[옵션 A] SSH 키 배포 (최초 1회)"
  echo ""

  if [[ ! -f ~/.ssh/id_rsa ]]; then
    echo "  RSA 키 생성 중..."
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
    echo "   OK... RSA 키 생성 완료: ~/.ssh/id_rsa"
  else
    echo "   OK... 기존 RSA 키 사용: ~/.ssh/id_rsa"
  fi

  if ! command -v sshpass &>/dev/null; then
    echo "  sshpass 설치 중..."
    apt install -y sshpass
  fi

  read -rsp "  Agent 서버 SSH 패스워드 입력: " SSH_PASS
  echo ""

  local success=0 fail=0

  for IP in "${AGENT_IPS[@]}"; do
    NAME=${SERVER_NAMES[$IP]}
    echo -n "  [$NAME / $IP] 공개키 배포 중... "
    if sshpass -p "$SSH_PASS" ssh-copy-id \
       -o StrictHostKeyChecking=no "${AGENT_USER}@${IP}" 2>/dev/null; then
      echo "OK"
      ((success++))
    else
      echo "FAIL"
      ((fail++))
    fi
  done

  echo ""
  echo "   OK... SSH 키 배포 완료 (성공: $success / 실패: $fail)"
}

# =============================================================
# Agent ossec.conf 설정 생성 함수
# =============================================================

# 공통 설정 (전 서버)
common_config() {
cat << 'CONF'
<ossec_config>

  # Manager 연결 설정
  <client>
    <server>
      <address>172.16.30.85</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
  </client>

  # 로그 수집: SSH 인증 (무단 접근 탐지 핵심)
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  # 로그 수집: 시스템 일반
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  # 로그 수집: 커널
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/kern.log</location>
  </localfile>

  # 로그 수집: 패키지 변경 감지
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/dpkg.log</location>
  </localfile>

  # FIM: 공통 감시 경로
  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>
    <alert_new_files>yes</alert_new_files>
    <directories check_all="yes" realtime="yes" report_changes="yes">/etc</directories>
    <directories check_all="yes" realtime="yes">/usr/bin,/usr/sbin,/bin,/sbin</directories>
    <directories check_all="yes" realtime="yes">/boot</directories>
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/random-seed</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore>/var/log</ignore>
    <ignore>/tmp</ignore>
    <ignore>/proc</ignore>
    <ignore>/sys</ignore>
    <ignore>/dev</ignore>
  </syscheck>

</ossec_config>
CONF
}

# k8s 노드 추가 설정
k8s_extra_config() {
cat << 'CONF'

  # 로그 수집: k8s 컨테이너 로그
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/containers/*.log</location>
  </localfile>

  # FIM: k8s 설정 경로
  <syscheck>
    <directories check_all="yes" realtime="yes">/etc/kubernetes</directories>
    <directories check_all="yes" realtime="yes">/etc/cni</directories>
  </syscheck>
CONF
}

# Vault 노드 추가 설정
vault_extra_config() {
cat << 'CONF'

  # FIM: Vault 설정 경로
  <syscheck>
    <directories check_all="yes" realtime="yes">/etc/vault.d</directories>
  </syscheck>
CONF
}

# HAProxy 노드 추가 설정
haproxy_extra_config() {
cat << 'CONF'

  # FIM: HAProxy 설정 경로
  <syscheck>
    <directories check_all="yes" realtime="yes">/etc/haproxy</directories>
  </syscheck>
CONF
}

# IP → 서버 유형 판별 후 설정 생성
build_config() {
  local IP="$1"
  local CONFIG
  CONFIG=$(common_config)

  for K8S_IP in "${K8S_IPS[@]}";     do [[ "$IP" == "$K8S_IP" ]]     && CONFIG+=$(k8s_extra_config)     && break; done
  for V_IP in "${VAULT_IPS[@]}";     do [[ "$IP" == "$V_IP" ]]       && CONFIG+=$(vault_extra_config)   && break; done
  for HA_IP in "${HAPROXY_IPS[@]}";  do [[ "$IP" == "$HA_IP" ]]      && CONFIG+=$(haproxy_extra_config) && break; done

  echo "$CONFIG"
}

# =============================================================
# [옵션 B] 원격 일괄 Agent 설정 주입 (SSH 키 방식)
# =============================================================
deploy_agent_config() {
  echo ""
  echo "[옵션 B] Agent 설정 원격 일괄 주입 (${#AGENT_IPS[@]}대)"
  echo ""

  local success=0 fail=0

  for IP in "${AGENT_IPS[@]}"; do
    NAME=${SERVER_NAMES[$IP]}
    echo -n "  [$NAME / $IP] 설정 주입 중... "

    CONFIG=$(build_config "$IP")

    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
       "${AGENT_USER}@${IP}" \
       "echo '$CONFIG' | sudo tee /var/ossec/etc/ossec.conf > /dev/null && \
        sudo systemctl restart wazuh-agent" 2>/dev/null; then
      echo "OK"
      ((success++))
    else
      echo "FAIL"
      ((fail++))
    fi
  done

  echo ""
  echo "   OK... 설정 주입 완료 (성공: $success / 실패: $fail)"
  [[ $fail -gt 0 ]] && echo "  [ERROR] 실패 서버는 아래 개별 명령어로 수동 처리하세요."
}

# =============================================================
# [옵션 C] 개별 서버 수동 실행 명령어 출력
# 원격 일괄 실패 시 또는 특정 서버만 재설정할 때 사용
# =============================================================
print_manual_commands() {
  echo ""
  echo "================================================================"
  echo " 개별 서버 수동 실행 명령어"
  echo "================================================================"
  echo ""
  echo "# [각 Agent 서버에 직접 SSH 접속 후 실행]"
  echo ""
  echo "# 1. ossec.conf 직접 편집"
  echo "#    sudo nano /var/ossec/etc/ossec.conf"
  echo ""
  echo "# 2. Agent 재시작"
  echo "#    sudo systemctl restart wazuh-agent"
  echo ""
  echo "# 3. Agent 상태 확인"
  echo "#    sudo systemctl status wazuh-agent"
  echo ""
  echo "# 4. Manager 연결 확인 (siem-01에서)"
  echo "#    sudo /var/ossec/bin/agent_control -l"
  echo ""
  echo "----------------------------------------------------------------"
  echo " 서버별 원격 개별 실행 (siem-01에서)"
  echo "----------------------------------------------------------------"
  echo ""
  for IP in "${AGENT_IPS[@]}"; do
    NAME=${SERVER_NAMES[$IP]}
    echo "# $NAME ($IP)"
    echo "ssh ${AGENT_USER}@${IP} 'sudo systemctl restart wazuh-agent'"
    echo ""
  done
}

# =============================================================
# 메인 실행
# =============================================================
echo "================================================================"
echo " Wazuh Agent 로그 수집 설정"
echo " Manager: $MANAGER_IP / 대상 Agent: ${#AGENT_IPS[@]}대"
echo "================================================================"
echo ""
echo "  1) SSH 키 배포        (최초 1회 - 패스워드 → 키 방식 전환)"
echo "  2) Agent 설정 일괄 주입 (원격 SSH 키 방식)"
echo "  3) 개별 서버 명령어 출력"
echo "  4) 전체 실행           (1 → 2 순서)"
echo ""
read -rp "선택 (1/2/3/4): " CHOICE

case "$CHOICE" in
  1) setup_ssh_key ;;
  2) deploy_agent_config ;;
  3) print_manual_commands ;;
  4) setup_ssh_key && deploy_agent_config ;;
  *) echo "[ERROR] 올바른 번호를 입력하세요 (1/2/3/4)"; exit 1 ;;
esac

echo ""
echo "================================================================"
echo "   OK... 01_agent_log_collect.sh 완료"
echo "================================================================"
