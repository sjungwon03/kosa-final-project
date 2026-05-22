# Wazuh 통합 보안 관제 시스템

Wazuh 기반 통합 보안 관제(SIEM) 환경에서 **로그 수집부터 Indexer 저장까지** 전 과정의 설정을 자동화한 스크립트 모음입니다.

> Wazuh Manager·Agent 설치는 Ansible로 별도 진행됩니다.  
> 이 레포지토리는 설치 이후 **로그 수집 정책 설정 및 데이터 흐름 구성**을 담당합니다.

---
## 아키텍처
<img width="1887" height="1153" alt="Wazuh 전체 구조" src="https://github.com/user-attachments/assets/b86f1708-5b6c-4a08-a6e1-1a293187bb90" />

| 컴포넌트 | 역할 | 포트 |
|---|---|---|
| Wazuh Agent | 각 서버 로그 수집 및 전송 | 1514 TCP (로그), 1515 TCP (등록) |
| Wazuh Manager | 로그 수신·분석·JSON 경고문 생성 | 514 UDP (pfSense Syslog) |
| Wazuh Indexer | JSON 데이터 저장 및 인덱싱 | 9200 TCP (RESTful API) |
| Wazuh Dashboard | 보안 이벤트 시각화 및 모니터링 | 443 HTTPS |

---
## 인프라 구성 (IP 목록)

| 서버명 | IP | 역할 |
|---|---|---|
| siem-01 | 172.16.30.85 | Wazuh Manager, Indexer, Dashboard |
| haproxy-01 | 172.16.20.26 | 로드밸런서 |
| haproxy-02 | 172.16.20.27 | 로드밸런서 |
| monitor-01 | 172.16.30.90 | 모니터링 서버 |
| k8s-master-01 | 172.16.30.30 | Kubernetes 마스터 |
| k8s-master-02 | 172.16.30.32 | Kubernetes 마스터 |
| k8s-master-03 | 172.16.30.33 | Kubernetes 마스터 |
| k8s-worker-01 | 172.16.30.45 | Kubernetes 워커 |
| k8s-worker-02 | 172.16.30.46 | Kubernetes 워커 |
| k8s-worker-03 | 172.16.30.47 | Kubernetes 워커 |
| k8s-worker-plat | 172.16.30.40 | Kubernetes 워커 (플랫폼) |
| **pfSense** | **172.16.30.1** | 최전방 방화벽 (Agentless) |

> monitor-01(.90/.91), k8s-master-01(.30/.31)은 VM 1대에 IP가 2개 할당된 구조입니다.  
> Agent는 VM당 1개 설치이므로 대표 IP 기준 총 10대입니다.  
> pfSense는 커널 충돌 우려로 Agent 설치X → 대신 514/UDP Syslog로 로그 수집합니다.

---
## 데이터 흐름

| ① Agent 수집 | ② Manager 정제 | ③ Indexer 저장 |
|---|---|---|
| 각 서버 로그 | 규칙 분석 후 JSON 경고문 생성 | OpenSearch에 날짜별 인덱스 자동 저장 |
| auth.log, syslog, FIM 변조 등 | `/var/ossec/logs/alerts/alerts.json` | Filebeat가 전달 |

---
## 디렉토리 구조

```
wazuh/
├── README.md                  # 이 파일
├── 00-wazuh_setup.md          # 각 스크립트 설계 의도 설명
├── 01-agent_log_collect.sh    # SSH 키 배포·Agent 등록·로그 수집 정책 원격 주입 (10대)
├── 02-manager_json_process.sh # Manager 로그 수신·JSON 정제 설정
├── 03-indexer_store.sh        # Indexer 데이터 저장 설정 (Filebeat)
├── 04-wazuh_all.sh            # 01~03 통합 실행
├── 05-pfsense_syslog.md       # pfSense Agentless Syslog 설정 방법
└── reports/
    ├── 01-k8s.md              # k8s 취약점 분석·보완 방안·조치 결과 (마스터3·워커3·워커플렛1)
    ├── 02-haproxy.md          # HAProxy 취약점 분석·보완 방안·조치 결과 (2대)
    └── 03-monitor.md          # Monitor 취약점 분석·보완 방안·조치 결과 (1대)
```

---

## 빠른 시작

### 통합 실행 (권장)
```bash
sudo chmod +x *.sh
sudo ./04-wazuh_all.sh
```

### 단계별 실행
```bash
# 1. Agent SSH 키 배포·등록·로그 수집 정책 설정 (10대 원격 일괄)
sudo ./01-agent_log_collect.sh

# 2. Manager JSON 정제 설정
sudo ./02-manager_json_process.sh

# 3. Indexer 저장 설정
sudo ./03-indexer_store.sh
```

---

## 보안 정책 요약

### 알람 임계치
| 레벨 | 기준 | 처리 |
|---|---|---|
| 1 ~ 2 | 일반 정보 | 미수집 |
| 3 ~ 9 | 주의 단계 | 로그 저장 |
| 10 이상 | 고위험 단계 | 즉시 알람 |

### FIM 감시 범위
| 경로 | 대상 서버 |
|---|---|
| `/etc`, `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`, `/boot` | 전 서버 공통 |
| `/etc/kubernetes`, `/etc/cni` | k8s 노드 |
| `/etc/haproxy` | HAProxy 서버 |
| `/etc/prometheus`, `/etc/grafana`, `/etc/alertmanager` | Monitor 서버 |

### 제외 경로 (오탐 방지)
`/var/log`, `/tmp`, `/proc`, `/sys`, `/dev`, `/etc/mtab` 등 변경이 잦은 경로

---

## 참고 문서
> [Wazuh 공식 문서](https://documentation.wazuh.com)  
> [ossec.conf 설정 가이드](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/)  
> [pfSense Agentless 설정](https://documentation.wazuh.com/current/user-manual/capabilities/agentless-monitoring/)
