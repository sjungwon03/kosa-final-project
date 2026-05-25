# 쉘 스크립트 설계 안내
이 문서는 `wazuh/` 디렉토리의 각 쉘 스크립트의 역할과 설계 의도를 설명합니다.

---
## 전체 구조 및 실행 순서
```
00-ssh_key_deploy.sh         → SSH 공개키 배포 (최초 1회 - 별도 실행)
        ↓
01-agent_log_collect.sh      → Agent 등록·로그 수집 정책 주입 (10대)
        ↓
02-manager_json_process.sh   → Manager 로그 수신·JSON 정제 설정
        ↓
03-pfsense_syslog.sh         → pfSense Agentless Syslog 설정
        ↓
04-indexer_store.sh          → Filebeat 설정·Indexer 저장
        ↓
05-active_response.sh        → Active Response 자동 차단 설정
```

> `06-wazuh_all.sh`는 01~05를 순서대로 한 번에 실행하는 통합 스크립트입니다.  
> `00-ssh_key_deploy.sh`는 최초 1회만 실행하므로 통합 스크립트에서 제외됩니다.

---
## 00-ssh_key_deploy.sh
### 역할
siem-01에서 10대 Agent 서버로 SSH 공개키를 일괄 배포합니다.  
패스워드 방식 → 키 방식으로 전환하여 이후 모든 원격 작업이 비밀번호 없이 가능하도록 합니다.

### 핵심 설계 결정
**왜 최초 1회만 실행하는가?**  
키 배포 완료 후에는 패스워드가 필요 없습니다.  
재실행해도 오류는 없지만 불필요한 패스워드 입력이 발생합니다.

### 실행 방법
```bash
./00-ssh_key_deploy.sh
# Agent 서버 SSH 패스워드 입력 후 10대 전체 배포
```

---
## 01-agent_log_collect.sh
### 역할
siem-01에서 10대 Agent 서버에 SSH로 원격 접속하여  
각 서버의 `ossec.conf`에 **로그 수집 정책을 주입**합니다.

### 핵심 설계 결정
**왜 원격 주입 방식인가?**  
10대 서버에 일일이 접속해 설정하는 것은 비효율적입니다.  
Wazuh Manager(siem-01) 한 곳에서 SSH로 일괄 처리합니다.

**왜 `echo '$CONFIG' | ssh` 대신 scp 방식을 사용하는가?**  
heredoc 내 싱글쿼트, XML 특수문자 이스케이프 오류가 발생할 수 있습니다.  
로컬에 임시 파일을 생성한 후 scp로 전송하는 방식으로 이를 방지합니다.

**서버 유형별 설정을 다르게 적용하는 이유**
| 서버 유형 | 추가 수집 항목 | 이유 |
|---|---|---|
| k8s 노드 (7대) | `/var/log/containers/*.log`, k8s Audit 로그, `/etc/kubernetes` FIM | 컨테이너 이상 행위·클러스터 설정 변조 탐지 |
| HAProxy (2대) | `/var/log/haproxy.log`, `/etc/haproxy` FIM | 로드밸런서 설정 변조 탐지 |
| monitor-01 (1대) | Prometheus·Grafana·Alertmanager 로그 및 FIM | 모니터링 스택 이상 행위 탐지 |

**공통 수집 로그**
| 로그 파일 | 수집 목적 |
|---|---|
| `/var/log/auth.log` | SSH 무단 접근·인증 실패 (핵심) |
| `/var/log/syslog` | 시스템 전반 이벤트 |
| `/var/log/kern.log` | 커널 이상 |
| `/var/log/dpkg.log` | 패키지 무단 설치·변경 |

**FIM 제외 경로**  
`/var/log`, `/tmp`, `/proc` 등은 정상 운영 중에도 끊임없이 변경됩니다.  
이를 감시하면 오탐이 폭발적으로 증가하므로 제외했습니다.

**이미 등록된 Agent 처리**  
Ansible로 사전 등록된 Agent는 재등록 시 `Duplicate` 오류가 발생합니다.  
스크립트에서 이를 정상으로 처리하여 FAIL 출력을 방지합니다.

### 스크립트 옵션 구조
```bash
./01-agent_log_collect.sh

# 1) Agent 등록 + 서비스 시작  → agent-auth 등록 후 wazuh-agent 시작
# 2) Agent 설정 일괄 주입      → 로그 수집 정책 주입
# 3) 개별 서버 명령어 출력     → 특정 서버만 재설정할 때
# 4) 전체 실행                 → 1 → 2 순서
```

---
## 02-manager_json_process.sh
### 역할
siem-01의 Wazuh Manager를 설정합니다.  
Agent·pfSense로부터 받은 로그를 **규칙에 따라 분석하고 JSON 경고문으로 정제**합니다.

### 핵심 설계 결정
**`jsonout_output: yes`로 설정한 이유**  
Indexer(OpenSearch)는 JSON 형식만 인식합니다.  
이 옵션이 활성화되어야 `alerts.json`이 생성되고 Filebeat가 Indexer로 전달할 수 있습니다.

**`logall: no`로 설정한 이유**  
모든 이벤트를 저장하면 디스크가 빠르게 소진됩니다.  
위협 이벤트(level 3 이상)만 저장해 리소스를 경량화합니다.

**포트별 역할**
| 포트 | 방향 | 용도 |
|---|---|---|
| 1515 TCP | Agent → Manager | Agent 최초 등록·인증 |
| 1514 TCP | Agent → Manager | 실시간 로그 전송 (암호화) |
| 514 UDP | pfSense → Manager | Agentless Syslog 수신 |

**pfSense에 Agent를 설치하지 않은 이유**  
pfSense는 실시간 패킷을 처리하는 방화벽 장비입니다.  
외부 프로그램(Agent)을 설치하면 커널 충돌 → 방화벽 마비 → 네트워크 전체 장애로 이어질 수 있습니다.  
대신 514/UDP Syslog로 원격 수집합니다.

**pfSense 커스텀 디코더·룰을 별도 등록하지 않는 이유**  
Wazuh 4.x부터 pfSense 룰/디코더가 기본 내장됩니다.  
커스텀 파일을 추가하면 충돌이 발생하므로 내장 파일을 사용합니다.

> 내장 경로:  
> `/var/ossec/ruleset/rules/0540-pfsense_rules.xml`  
> `/var/ossec/ruleset/decoders/0455-pfsense_decoders.xml`

**재시작을 스크립트에 포함하지 않은 이유**  
ossec.conf 수정 후 재시작 시 설정 오류로 Manager가 다운될 수 있습니다.  
문법 검증 후 수동 재시작을 권장합니다.

### 생성되는 핵심 파일
```
/var/ossec/logs/alerts/alerts.json   # 정제된 JSON 경고문 (Filebeat가 Indexer로 전달)
/var/ossec/logs/alerts/alerts.log    # 텍스트 형식 경고문 (로컬 확인용)
```

### 스크립트 옵션 구조
```bash
./02-manager_json_process.sh

# 1) 수신 설정 확인  → 포트 상태·ossec.conf 현황
# 2) 수신 설정 주입  → TCP 1514 + UDP 514 remote 블록 삽입
# 3) JSON 출력 설정  → alerts.json 활성화 및 샘플 확인
# 4) 설정 검증       → 문법 검증·포트 확인
# 5) 전체 실행       → 2 → 3 → 4 순서
```

---
## 03-pfsense_syslog.sh
### 역할
Wazuh Agent를 설치할 수 없는 pfSense(최전방 방화벽)의 로그를  
**514/UDP Syslog**로 원격 수집하는 설정을 자동화합니다.

### pfSense에 Agent를 설치하지 않는 이유
pfSense는 실시간 패킷을 처리하는 방화벽 장비입니다.  
외부 프로그램(Wazuh Agent)을 설치하면 커널 충돌이 발생할 수 있고,  
이는 방화벽 마비 → 네트워크 전체 장애로 이어질 수 있습니다.  
대신 pfSense가 기본 지원하는 **Syslog 원격 전송(514/UDP)** 으로 로그를 수집합니다.

> 방화벽이 뚫리더라도 내부 10대 서버 전부 Agent가 설치되어 있어 위협을 탐지할 수 있습니다.

### pfSense Syslog 설정 방법 (Web UI)
**1. pfSense 웹 콘솔 접속**
```
https://172.16.30.1
```

**2. Syslog 설정 메뉴 이동**
```
Status > System Logs > Settings
```

**3. Remote Logging Options 설정**
| 항목 | 값 |
|---|---|
| Enable Remote Logging | ✔ 체크 |
| Remote log servers IP | 172.16.30.85 |
| Remote log servers Port | 514 |
| Protocol | UDP |

**4. Remote Syslog Contents 항목 체크**
| 항목 | 수집 목적 |
|---|---|
| ✔ Firewall Events | 방화벽 차단·허용 로그 |
| ✔ General Authentication Events | 인증 로그 |
| ✔ DHCP Events | IP 할당 로그 |
| ✔ VPN Events | VPN 접속 로그 |

**5. Save 클릭**
### pfSense Syslog 설정 방법 (Shell Script)
Web UI 대신 `03-pfsense_syslog.sh`를 사용하면  
siem-01에서 pfSense에 SSH로 원격 접속하여 자동으로 설정할 수 있습니다.

```bash
# 사전 준비: pfSense로 SSH 키 배포 (최초 1회)
ssh-copy-id root@172.16.30.1

# 스크립트 실행
sudo ./03-pfsense_syslog.sh
```

### 수신 확인
```bash
# pfSense Syslog 수신 여부 실시간 확인
sudo tcpdump -i any udp port 514
```

### 주의사항
> **02-manager_json_process.sh 선행 필요** — ossec.conf에 Syslog 수신 설정이 없으면 스크립트가 중단됩니다.  
> **pfSense SSH 활성화 확인** — `System > Advanced > Admin Access > Secure Shell` 항목이 활성화되어 있어야 합니다.

---

## 04-indexer_store.sh
### 역할
Filebeat를 설정하여 Manager의 `alerts.json`을 읽어  
**Indexer(OpenSearch, 9200/TCP)로 전달**하고 인덱싱합니다.

### 핵심 설계 결정
**Filebeat를 사용하는 이유**  
Manager와 Indexer 사이의 데이터 전달 브릿지 역할입니다.  
전송 실패 시 재시도, 버퍼링, TLS 처리 등을 Filebeat가 담당합니다.

**패스워드를 하드코딩하지 않는 이유**  
스크립트 실행 시 런타임에 입력받습니다.  
패스워드가 파일에 남으면 git에 올렸을 때 보안 사고로 이어질 수 있습니다.

**날짜별 인덱스 자동 생성**  
`wazuh-alerts-4.x-2026.05.24` 형태로 날짜별 인덱스가 생성됩니다.  
오래된 인덱스만 선택적으로 삭제해 스토리지를 관리할 수 있습니다.

**SSL 검증 비활성화 이유**  
Ansible 설치 시 인증서가 `127.0.0.1`로 발급되어 `172.16.30.85`로 접근 시 x509 오류 발생.  
내부망 환경이므로 `ssl.verification_mode: none`으로 우회합니다.

**Filebeat seccomp 이슈**  
Ubuntu 환경에서 seccomp(보안 컴퓨팅 모드)가 Filebeat의 스레드 생성을 차단하는 문제 발생.  
systemd override로 `SecureBits=` 설정을 해제하여 해결합니다.

```bash
sudo mkdir -p /etc/systemd/system/filebeat.service.d
sudo tee /etc/systemd/system/filebeat.service.d/override.conf << 'EOF'
[Service]
SecureBits=
EOF
sudo systemctl daemon-reload
```

### 스크립트 옵션 구조
```bash
./04-indexer_store.sh

# 1) 사전 환경 확인  → Filebeat·Indexer 상태 점검
# 2) filebeat.yml 작성  → alerts.json → Indexer 전달 설정
# 3) Filebeat 재시작
# 4) 인덱스 저장 확인  → 인덱스 목록·클러스터 상태·샘플 조회
# 5) 전체 실행  → 1 → 2 → 3 → 4 순서
```

---
## 05-active_response.sh
### 역할
Wazuh Manager의 Active Response 기능을 설정합니다.  
탐지된 위협에 대해 Agent가 **자동으로 공격 IP를 차단**합니다.

### 동작 흐름
```
Manager 룰 매칭 (level 임계값 초과)
→ Manager가 해당 Agent에 명령 전달
→ Agent가 자기 서버에서 iptables firewall-drop 실행
→ 설정된 timeout 후 자동 해제
```

### 차단 정책
| 탐지 조건 | 차단 범위 | 자동 해제 | 룰 ID |
|---|---|---|---|
| SSH 브루트포스 | 해당 서버만 (local) | 10분 후 | 5720 |
| SSH 인증 반복 실패 | 해당 서버만 (local) | 10분 후 | 5763 |
| pfSense 포트스캔 | 전체 10대 (all) | 30분 후 | 100201 |
| OpenVPN 브루트포스 | 전체 10대 (all) | 30분 후 | 100211 |

**location 옵션 설명**
- `local`: 룰이 발생한 Agent 서버에서만 차단
- `all`: 전체 Agent 서버에 차단 전파

### 스크립트 옵션 구조
```bash
./05-active_response.sh

# 1) 사전 환경 확인  → AR 스크립트·현재 설정 상태
# 2) AR 설정 주입    → SSH·포트스캔·OpenVPN 자동 차단
# 3) 검증            → 문법 검증·설정 확인
# 4) 차단 이력 확인  → 실행 로그·현재 차단 IP
# 5) 전체 실행       → 1 → 2 → 3 순서
```

---
## 06-wazuh_all.sh
### 역할
01~05 스크립트를 순서대로 통합 실행합니다.  
각 STEP 실패 시 계속 진행 여부를 묻고 실행 로그를 파일로 저장합니다.

### 주의사항
> **00-ssh_key_deploy.sh는 포함되지 않습니다.** 최초 1회만 실행하므로 별도로 진행하세요.  
> **재시작은 수동으로 진행합니다.** 설정 오류로 인한 서비스 다운을 방지합니다.  
> **03-pfsense_syslog.sh는 sudo로 실행됩니다.** root 권한이 필요합니다.

### 스크립트 옵션 구조
```bash
./06-wazuh_all.sh

# 1) 전체 실행  → STEP 1 → 2 → 3 → 4 → 5
# 2) STEP 1만   → Agent 등록 및 로그수집정책
# 3) STEP 2만   → Manager 수신 설정
# 4) STEP 3만   → pfSense Syslog
# 5) STEP 4만   → Indexer 저장
# 6) STEP 5만   → Active Response
```

---
## 공통 설계 원칙
**백업 우선**  
모든 설정 파일 수정 전 타임스탬프 백업을 생성합니다.
```
/var/ossec/etc/ossec.conf.bak.20260524_202548
```

**재시작 미포함**  
스크립트 내부에서 서비스 재시작을 하지 않습니다.  
설정 오류로 인한 서비스 다운을 방지하기 위해 수동 재시작을 권장합니다.

**단계별 상태 확인**  
각 스크립트는 실행 완료 후 포트 리스닝·서비스 상태를 출력합니다.

**`OK` / `ERROR` 출력 통일**  
성공은 `OK...`, 실패는 `[ERROR]`로 구분해 로그 파싱이 용이합니다.

**`set -euo pipefail`**  
오류 발생 시 즉시 스크립트를 종료합니다.  
파이프라인 중간 오류도 감지합니다.
