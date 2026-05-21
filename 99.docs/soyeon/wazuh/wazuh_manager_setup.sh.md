# 쉘 스크립트 작성 안내

이 문서는 `wazuh/` 디렉토리의 각 쉘 스크립트의 역할과 저의를 설명하는 파일입니다.

---

## 전체 구조 및 실행 순서

```
01_agent_log_collect.sh      → Agent 19대에 로그 수집 정책 주입
        ↓
02_manager_json_process.sh   → Manager가 받은 로그를 JSON으로 정제
        ↓
03_indexer_store.sh          → 정제된 JSON을 Indexer에 저장
        ↓
04_dashboard_export.sh       → Dashboard에서 데이터 조회 가능하도록 설정
```

> `wazuh_all_in_one.sh`은 위 4개를 순서대로 한 번에 실행하는 통합 스크립트입니다.

---

## 01_agent_log_collect.sh

### 역할
siem-01에서 19대 Agent 서버에 SSH로 원격 접속하여 각 서버의 `ossec.conf`(Agent 설정 파일)에 **어떤 로그를 수집할지** 주입합니다.

### 핵심 설계 결정

**왜 원격 주입 방식인가?**  
19대 서버에 일일이 접속해 설정하는 것은 비효율적입니다. siem-01 한 곳에서 SSH로 일괄 처리합니다.

**SSH 키 배포를 옵션 A로 분리한 이유**  
최초 1회만 필요한 작업이기 때문입니다. 키 배포 후에는 옵션 B(설정 주입)만 반복 실행하면 됩니다.

**서버 유형별 설정을 다르게 적용하는 이유**

| 서버 유형 | 추가 수집 항목 | 이유 |
|---|---|---|
| k8s 노드 | `/var/log/containers/*.log`, `/etc/kubernetes` FIM | 컨테이너 이상 행위·클러스터 설정 변조 탐지 |
| Vault | `/etc/vault.d` FIM | 시크릿 관리 설정 무단 변경 탐지 |
| HAProxy | `/etc/haproxy` FIM | 로드밸런서 설정 변조 탐지 |

**공통 수집 로그**

| 로그 파일 | 수집 목적 |
|---|---|
| `/var/log/auth.log` | SSH 무단 접근·인증 실패 (핵심) |
| `/var/log/syslog` | 시스템 전반 이벤트 |
| `/var/log/kern.log` | 커널 이상 |
| `/var/log/dpkg.log` | 패키지 무단 설치·변경 |

**FIM 제외 경로 설정 이유**  
`/var/log`, `/tmp`, `/proc` 등은 정상 운영 중에도 끊임없이 변경됩니다. 이를 감시하면 오탐이 폭발적으로 증가하므로 제외합니다.

### 실행 옵션

```bash
sudo ./01_agent_log_collect.sh
# 1) SSH 키 배포     → 최초 1회
# 2) 설정 일괄 주입  → 매 설정 변경 시
# 3) 개별 명령어 출력 → 특정 서버만 재설정할 때
# 4) 전체 실행       → 1 → 2 순서
```

---

## 02_manager_json_process.sh

### 역할
siem-01의 Wazuh Manager `ossec.conf`를 설정합니다.  
Agent로부터 받은 로그를 **규칙(rules)에 따라 분석하고 JSON 경고문으로 정제**하는 것이 핵심입니다.

### 핵심 설계 결정

**`jsonout_output: yes`로 설정한 이유**  
Indexer(OpenSearch)는 JSON 형식만 인식합니다. 이 옵션이 활성화되어야 `alerts.json`이 생성되고 Filebeat가 Indexer로 전달할 수 있습니다.

**`logall: no`로 설정한 이유**  
모든 이벤트를 저장하면 디스크가 빠르게 소진됩니다. 위협 이벤트(level 3 이상)만 저장해 리소스를 경량화합니다.

**포트별 역할**

| 포트 | 방향 | 용도 |
|---|---|---|
| 1515 TCP | Agent → Manager | Agent 최초 등록·인증 |
| 1514 TCP | Agent → Manager | 실시간 로그 전송 (암호화) |
| 514 UDP | pfSense → Manager | Agentless Syslog 수신 |

**pfSense에 Agent를 설치하지 않은 이유**  
pfSense는 실시간 패킷을 처리하는 방화벽 장비입니다. 외부 프로그램(Agent)을 설치하면 커널 충돌이 발생할 수 있고, 이는 방화벽 마비 → 네트워크 전체 장애로 이어질 수 있습니다. 대신 514/UDP Syslog로 원격 수집합니다.

**Active Response 설정**  
SSH 브루트포스(rule 5763) 탐지 시 해당 IP를 10분간 자동 차단합니다. 수동 대응 없이 즉각적인 위협 억제가 가능합니다.

### 생성되는 핵심 파일

```
/var/ossec/logs/alerts/alerts.json   # 정제된 JSON 경고문 (Filebeat가 읽어 Indexer로 전달)
/var/ossec/logs/alerts/alerts.log    # 텍스트 형식 경고문 (로컬 확인용)
```

---

## 03_indexer_store.sh

### 역할
Filebeat를 설정하여 Manager의 `alerts.json`을 읽어 **Indexer(OpenSearch, 9200/TCP)로 전달**하고 인덱싱합니다.

### 핵심 설계 결정

**Filebeat를 사용하는 이유**  
Manager와 Indexer 사이의 데이터 전달 브릿지 역할입니다. Manager가 직접 Indexer에 쓰지 않고 Filebeat를 거치는 이유는 전송 실패 시 재시도, 버퍼링, TLS 인증서 처리 등을 Filebeat가 담당하기 때문입니다.

**날짜별 인덱스 자동 생성**  
`wazuh-alerts-4.x-2025.05.21` 형태로 날짜별 인덱스가 생성됩니다. 오래된 인덱스만 선택적으로 삭제해 스토리지를 관리할 수 있습니다.

**`archives: false`로 설정한 이유**  
전체 로그(정상 포함)를 저장하면 Indexer 용량이 급증합니다. 위협 이벤트(alerts)만 저장합니다.

---

## 04_dashboard_export.sh

### 역할
Indexer에 저장된 데이터를 **Dashboard 웹 UI에서 조회할 수 있도록** 인덱스 패턴을 등록하고 접속 정보를 안내합니다.

### 핵심 설계 결정

**인덱스 패턴 등록이 필요한 이유**  
Dashboard는 Indexer의 어떤 인덱스를 보여줄지 패턴으로 인식합니다. `wazuh-alerts-4.x-*` 패턴을 등록해야 날짜별로 쌓이는 인덱스를 하나의 뷰로 조회할 수 있습니다.

**자동 등록 실패 시 수동 방법**
```
https://172.16.30.85 접속
→ Management → Stack Management → Index Patterns → Create index pattern
→ 패턴명: wazuh-alerts-4.x-*
→ 시간 필드: timestamp
```

---

## 공통 설계 원칙

**백업 우선**  
모든 설정 파일 수정 전 타임스탬프 백업을 생성합니다. 문법 오류 감지 시 자동 복구합니다.

**단계별 상태 확인**  
각 스크립트는 실행 완료 후 포트 리스닝·서비스 상태·연결 확인 명령어를 출력합니다.

**`OK` / `ERROR` 출력 통일**  
성공은 `OK...`, 실패는 `[ERROR]`로 구분해 로그 파싱이 용이합니다.

**`set -euo pipefail`**  
오류 발생 즉시 스크립트를 종료합니다. 잘못된 설정이 다음 단계로 넘어가는 것을 방지합니다.
