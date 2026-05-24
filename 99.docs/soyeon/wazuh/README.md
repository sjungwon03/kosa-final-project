# Wazuh 기반 통합 보안 관제 시스템
> Proxmox VM(siem-01) 위에서 동작하는 Wazuh 기반 SIEM 환경의  
> **로그 수집 정책 설정 및 보안 자동화**를 담당하는 레포지토리입니다.

---
## 프로젝트 소개
Wazuh Manager·Agent 설치(Ansible) 이후, **로그 수집부터 Indexer 저장·자동 차단까지**  
전 과정을 쉘 스크립트로 자동화했습니다.

- 10대 Agent 서버에 로그 수집 정책 원격 일괄 주입
- pfSense 방화벽 Agentless Syslog 연동
- Filebeat를 통한 Indexer 저장
- SSH 브루트포스·포트스캔·OpenVPN 브루트포스 탐지 시 자동 차단 (Active Response)

---
## 개발 환경
| 항목 | 내용 |
|---|---|
| OS | Ubuntu 24.04 |
| 플랫폼 | Proxmox VM (siem-01) |
| Shell | Bash |

---
## 기술 스택
| 분류 | 기술 |
|---|---|
| SIEM | Wazuh 4.14.5 (Manager / Agent / Indexer / Dashboard) |
| 검색 엔진 | OpenSearch (Wazuh Indexer) |
| 로그 수집 | Filebeat |
| 방화벽 | pfSense |
| 컨테이너 | Kubernetes |
| 자동화 | Bash Shell Script |
| 설치 자동화 | Ansible (별도 진행) |

---
## 아키텍처
| 컴포넌트 | 역할 | 포트 |
|---|---|---|
| Wazuh Agent | 각 서버 로그 수집 및 전송 | 1514 TCP (로그), 1515 TCP (등록) |
| Wazuh Manager | 로그 수신·분석·JSON 경고문 생성 | 514 UDP (pfSense Syslog) |
| Wazuh Indexer | JSON 데이터 저장 및 인덱싱 | 9200 TCP |
| Wazuh Dashboard | 보안 이벤트 시각화 | 443 HTTPS |

<img width="656" alt="Wazuh 전체 구조" src="https://github.com/user-attachments/assets/8c992296-7f60-41c8-9036-9f8bd0626c94" />

---
## 인프라 구성
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
| pfSense | 172.16.30.1 | 최전방 방화벽 (Agentless) |

> pfSense는 커널 충돌 우려로 Agent 설치 제외 → 514/UDP Syslog로 로그 수집

---
## 주요 기능
### 데이터 흐름
```
각 서버 로그 (auth.log, syslog, FIM 등)
        ↓ Wazuh Agent (TCP 1514)
Wazuh Manager → 규칙 분석 → alerts.json 생성
        ↓ Filebeat
Wazuh Indexer (OpenSearch) → 날짜별 인덱스 저장
        ↓
Wazuh Dashboard → 시각화
```

### Active Response 차단 정책
| 탐지 조건 | 차단 범위 | 자동 해제 | 룰 ID |
|---|---|---|---|
| SSH 브루트포스 | 해당 서버만 | 10분 후 | 5720 |
| SSH 인증 반복 실패 | 해당 서버만 | 10분 후 | 5763 |
| pfSense 포트스캔 | 전체 10대 | 30분 후 | 100201 |
| OpenVPN 브루트포스 | 전체 10대 | 30분 후 | 100211 |

### FIM 감시 범위
| 경로 | 대상 서버 |
|---|---|
| `/etc`, `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`, `/boot` | 전 서버 공통 |
| `/etc/kubernetes`, `/etc/cni` | k8s 노드 |
| `/etc/haproxy` | HAProxy |
| `/etc/prometheus`, `/etc/grafana`, `/etc/alertmanager` | Monitor |

---
## 디렉토리 구조
```
wazuh/
├── README.md                   # 이 파일
├── Wazuh_Setup.md              # 각 스크립트 설계 의도 설명
├── trouble.md                  # 트러블슈팅
├── 00-ssh_key_deploy.sh        # SSH 공개키 배포 (최초 1회 - 별도 실행)
├── 01-agent_log_collect.sh     # Agent 등록·로그수집정책 원격주입 (10대)
├── 02-manager_json_process.sh  # Manager 로그 수신·JSON 정제 설정
├── 03-pfsense_syslog.sh        # pfSense Agentless Syslog 설정
├── 04-indexer_store.sh         # Indexer 데이터 저장 설정 (Filebeat)
├── 05-active_response.sh       # Active Response 자동 차단 설정
├── 06-wazuh_all.sh             # 01~05 통합 실행
└── config/
    ├── config.yml              # Wazuh 인증서 발급용 노드 설정
    └── certs/                  # 발급된 인증서 보관
```

---
## 설치 및 실행 방법
### 사전 준비
```bash
# Wazuh Manager·Agent 설치는 Ansible로 별도 진행
# 이 레포지토리는 설치 이후 설정 자동화를 담당합니다

# 스크립트 실행 권한 부여
chmod +x ~/wazuh/0*.sh

# 작업 디렉터리로 이동
cd ~/wazuh
```

### SSH 공개키 배포 (최초 1회)
```bash
./00-ssh_key_deploy.sh
```

### 통합 실행
```bash
# 01 → 02 → 03 → 04 → 05 순서 자동 실행
./06-wazuh_all.sh
```

### 개별 실행
```bash
./01-agent_log_collect.sh    # Agent 등록 및 로그 수집 정책 주입
./02-manager_json_process.sh # Manager 수신 설정 및 JSON 출력
./03-pfsense_syslog.sh       # pfSense Syslog 설정
./04-indexer_store.sh        # Filebeat 설정 및 Indexer 저장
./05-active_response.sh      # Active Response 설정
```

---
## 참고 문서
- [Wazuh 공식 문서](https://wazuh.com)
- [ossec.conf 설정 가이드](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/)
- [pfSense Agentless 설정](https://documentation.wazuh.com/current/user-manual/capabilities/agentless-monitoring/)
