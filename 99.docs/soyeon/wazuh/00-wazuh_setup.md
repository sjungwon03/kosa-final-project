# 쉘 스크립트 설계 안내  
이 문서는 `wazuh/` 디렉토리의 각 쉘 스크립트의 역할과 의미를 설명합니다.

---
## 전체 구조 및 실행 순서
```
01-agent_log_collect.sh      → SSH 키 배포·Agent 등록·로그 수집 정책 주입 (10대)
        ↓
02-manager_json_process.sh   → Manager가 받은 로그를 JSON으로 정제
        ↓
03-indexer_store.sh          → 정제된 JSON을 Indexer에 저장
```

> `04-wazuh_all.sh`는 위 3개를 순서대로 한 번에 실행하는 통합 스크립트입니다.  
> pfSense Syslog 설정은 `05-pfsense_syslog.md`를 참고하세요.

---
## 01-agent_log_collect.sh

### 역할
siem-01에서 10대 Agent 서버에 SSH로 원격 접속하여 각 서버의 `ossec.conf`에  
**어떤 로그를 수집할지 정책을 주입**합니다.

### 핵심 설계 결정
**왜 원격 주입 방식인가?**  
물론 `sudo vim /var/ossec/etc/ossec.conf && sudo systemctl restart wazuh-agent` 명령을 사용해 개별적으로 설정할 수도 있지만,  
10대 서버에 일일이 접속해 설정하는 것은 비효율적입니다.  
따라서 wauzh manager(siem-01) 서버 한 곳에서 ssh로 일괄 처리하는 방법을 채택했습니다.

**왜 `echo '$CONFIG' | ssh` 명령 대신 scp 방식을 사용하는가?**  
heredoc 내 single quote, XML 특수문자 이스케이프 오류가 발생할 수 있습니다.  
로컬에 임시 파일을 생성한 후 scp로 전송하는 방식으로 이를 방지합니다.

**서버 유형별 설정을 다르게 적용하는 이유**
| 서버 유형 | 추가 수집 항목 | 이유 |
|---|---|---|
| k8s 노드 (7대) | `/var/log/containers/*.log`, `/etc/kubernetes` FIM | 컨테이너 이상 행위·클러스터 설정 변조 탐지 |
| HAProxy (2대) | `/etc/haproxy` FIM | 로드밸런서 설정 변조 탐지 |
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

### 실행될 스크립트 구조 설명(01)
```bash
sudo ./01-agent_log_collect.sh

# 1) SSH 키 배포              → 최초 1회 (패스워드 → 키 방식 전환)
# 2) Agent 등록 + 서비스 시작 → agent-auth 등록 후 wazuh-agent 시작
# 3) Agent 설정 일괄 주입     → 로그 수집 정책 주입 (매 설정 변경 시)
# 4) 개별 서버 명령어 출력    → 특정 서버만 재설정할 때
# 5) 전체 실행                → 1 → 2 → 3 순서
```

---
## 02-manager_json_process.sh

### 역할
siem-01의 Wazuh Manager를 설정합니다.  
Agent·pfSense로부터 받은 로그를 **규칙(rules)에 따라 분석하고 JSON 경고문으로 정제**하는 것이 핵심입니다.

### 핵심 설계 결정
**`jsonout_output: yes`로 설정한 이유**  
Indexer(OpenSearch)는 JSON 형식만 인식합니다. 이 옵션이 활성화되어야  
`alerts.json`이 생성되고 Filebeat가 Indexer로 전달할 수 있습니다.

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

**pfSense 커스텀 디코더·룰을 별도 등록하는 이유**  
pfSense는 BSD syslog 포맷으로 전송합니다.  
Wazuh 기본 디코더로도 파싱되지만, 방화벽 룰·인터페이스 필드 추출과  
포트스캔·VPN 브루트포스·설정 변경 등 pfSense 전용 위협 탐지를 위해 커스텀 디코더·룰을 추가합니다.

### 생성되는 핵심 파일
```
/var/ossec/logs/alerts/alerts.json   # 정제된 JSON 경고문 (Filebeat가 읽어 Indexer로 전달)
/var/ossec/logs/alerts/alerts.log    # 텍스트 형식 경고문 (로컬 확인용)
```

### 실행될 스크립트 구조 설명(02)
```bash
sudo ./02-manager_json_process.sh

# 1) 수신 설정 확인       → 포트 상태·ossec.conf 현황
# 2) 수신 설정 주입       → TCP 1514 + UDP 514 remote 블록 삽입
# 3) pfSense 디코더 등록  → filterlog·openvpn·dhcp·php
# 4) pfSense 룰 등록      → 포트스캔·VPN 브루트포스·설정 변경 탐지
# 5) JSON 출력 설정       → alerts.json 활성화 및 샘플 확인
# 6) Manager 재시작·검증  → 문법 검증·재시작·포트 확인
# 7) 전체 실행            → 2 → 3 → 4 → 5 → 6 순서
```

---
## 03-indexer_store.sh

### 역할
Filebeat를 설정하여 Manager의 `alerts.json`을 읽어  
**Indexer(OpenSearch, 9200/TCP)로 전달**하고 인덱싱합니다.

### 핵심 설계 결정
**Filebeat를 사용하는 이유**  
Manager와 Indexer 사이의 데이터 전달 브릿지 역할입니다.  
전송 실패 시 재시도, 버퍼링, TLS 인증서 처리 등을 Filebeat가 담당합니다.

**패스워드를 하드코딩하지 않는 이유**  
스크립트 실행 시 런타임에 입력받습니다.  
패스워드가 파일에 남으면 git에 올렸을 때 보안 사고로 이어질 수 있습니다.

**날짜별 인덱스 자동 생성**  
`wazuh-alerts-4.x-2025.05.21` 형태로 날짜별 인덱스가 생성됩니다.  
오래된 인덱스만 선택적으로 삭제해 스토리지를 관리할 수 있습니다.

**`archives: false`로 설정한 이유**  
전체 로그(정상 포함)를 저장하면 Indexer 용량이 급증합니다.  
위협 이벤트(alerts)만 저장합니다.

### 실행될 스크립트 구조 설명(03)
```bash
sudo ./03-indexer_store.sh

# 1) 사전 환경 확인     → Filebeat·인증서·Indexer 상태 점검
# 2) filebeat.yml 작성  → alerts.json → Indexer 전달 설정
# 3) Filebeat 재시작
# 4) 인덱스 저장 확인   → 인덱스 목록·클러스터 상태·샘플 조회
# 5) 전체 실행          → 1 → 2 → 3 → 4 순서
```

---
## 공통 설계 원칙
**백업 우선**  
모든 설정 파일 수정 전 타임스탬프 백업을 생성합니다.  
문법 오류 감지 시 자동 복구합니다.

**단계별 상태 확인**  
각 스크립트는 실행 완료 후 포트 리스닝·서비스 상태·연결 확인 명령어를 출력합니다.

**`OK` / `ERROR` 출력 통일**  
성공은 `OK...`, 실패는 `[ERROR]`로 구분해 로그를 파싱할 때 용이합니다.
> *파싱: 크롤링한 정보 중 인간이 읽을 수 있고, 필요한 정보만 뽑는 것

**`set -euo pipefail`**  
오류 발생 즉시 스크립트를 종료합니다.  
잘못된 설정이 다음 단계로 넘어가는 것을 방지합니다.
