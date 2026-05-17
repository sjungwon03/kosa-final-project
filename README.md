# KOSA 최종프로젝트 - 4팀

[TODO] 프로젝트 개요 작성 필요 (목적, 구성 범위, 팀 역할 등)

**목차**

- [레포지터리 구조](#레포지터리-구조)
- [서비스 접근 아키텍처](#서비스-접근-아키텍처)
- [인프라 설계 원칙](#인프라-설계-원칙)
- [의도적 트레이드오프](#의도적-트레이드오프)
- [구성 순서](#구성-순서)

> 본 프로젝트는 LLM(AI Pair Programmer)을 사용하여 인프라 리서치 및 설계 검증 도구로 활용하였습니다.

## 레포지터리 구조

```bash
├── 00.scripts/         # Proxmox 베이스 템플릿 생성 스크립트
├── 01.packer/          # 공통 VM 템플릿 이미지 빌드
├── 02.terraform/       # Proxmox VM 프로비저닝 (IaC)
├── 03.ansible/         # OS 설정 및 서비스 오케스트레이션
├── 04.k8s/             # Kubernetes 리소스 매니페스트 (YAML)
├── 05.cicd/            # Gitea + act_runner 인프라 CI (Terraform/Ansible 자동화, Nexus 미러링)
├── 06.argocd/          # ArgoCD GitOps CD — 웹앱 서비스 K8s 배포 (팀원 담당)
├── 70.security/        # 보안 관제 및 에이전트 설정 (Wazuh)
├── 80.monitoring/      # 관측성 스택 구축 (PLG)
└── 99.docs/            # 프로젝트 통합 산출물
```

## 서비스 접근 아키텍처

**외부 접속 및 트래픽 흐름**

- 외부 사용자 -> pfSense 공인 IP -> pfSense (Port Forwarding) -> HAProxy VIP (172.16.20.25) -> 내부 서비스
- HAProxy L7 라우팅: HTTP Host 헤더(도메인) 기반으로 내부 서비스 분기 (Gitea, Nexus 등)

```text
+-----------------------+
|     External User     |
+-----------+-----------+
            │
            ▼
+-----------+-----------+
|        pfSense        | (NAT/Port Forwarding)
+-----------+-----------+
            │
            ▼
+-----------+-----------+
|        HAProxy        | (VIP: 172.16.20.25)
+-----------+-----------+
            │
            ├─ [ Git / Nexus ]
            ├─ [ K8s Cluster ]
            └─ [ Vault / Monitoring ]
```

**CI/CD 파이프라인 흐름**

- 인프라 CI (외부 VM): Gitea + act_runner (Terraform/Ansible 자동화, Nexus 패키지 미러링)
- 앱 CI/CD (K8s 내부): GitLab + ArgoCD (서비스 빌드·테스트·K8s 자동 배포)

```text
  [인프라 CI]                          [앱 CI/CD]
  Gitea (VM .55)                       GitLab (K8s 내부)
      │ trigger                             │ trigger
      ▼                                     ▼
  act_runner  ──► Terraform/Ansible     act_runner ──► build/test
  (VM .55)    ──► Nexus 미러링                        ──► image push → Nexus
                                             │
                                        ArgoCD (K8s 내부)
                                             │ watch manifest
                                             ▼
                                         K8s Deploy
```

## 인프라 설계 원칙

**운영 및 자동화 전략**

- 수동 설치: 구조 변화가 적고 GUI 설정이 유리한 도구 (ex. pfSense)
- 자동화: 설정이 잦고 스케일링이 필요한 서비스 (ex. K8s, IaC)

**네트워크 및 보안**

- 보안 컴플라이언스 준수를 위한 물리/논리적 망 분리 (VLAN 20/30)
- 인프라 제약 시 유연한 대응이 가능한 아이피 체계 구축 (단일망 전환 가능)
- 모든 외부 인입은 pfSense와 HAProxy VIP로 제한하여 공격 표면 최소화

**가용성 및 서비스 연속성**

- 단일 장애점(SPOF) 제거를 위한 노드 분산 배치 및 VIP(Keepalived) 도입
- 관리 서비스 독립성: CICD, Registry, Vault, MinIO를 K8s 외부에 구성하여 순환 의존성(Ouroboros) 방지
- 스토리지 이원화: 제어부(Local-LVM)와 데이터부(RBD) 분리로 안정성 및 확장성 확보

> 우로보로스(Ouroboros): A를 고치기 위해 B가 필요한데, B가 작동하려면 A가 살아있어야 하는 상황

## 의도적 트레이드오프

**pfSense (SPOF)**

- 네트워크의 최전방 접점으로서 단일 구성됨 (향후 필요시 HA 구성 고려)

**Platform Worker (SPOF)**

- ArgoCD 등 인프라 지원용 파드만 구동되므로 일시적 장애가 실제 서비스 중단을 초래하지 않음

## 구성 순서

### 인터넷 연결 단계

인터넷 접근이 가능한 상태에서 진행 (VLAN 30 allow-all 상태)

1. pfSense: 방화벽, NAT, WireGuard VPN (수동)
2. Control: Terraform, Ansible 컨트롤 노드 (스크립트)
3. DNS: CoreDNS, etcd, Keepalived VIP
4. MinIO: Terraform state backend
5. SIEM: Wazuh manager
6. Monitor: PLG 스택, Keepalived VIP (promtail 로그 수집)
7. Vault: HashiCorp Vault HA (서비스 시크릿 관리)
8. HAProxy: L4 로드밸런서, Keepalived VIP
9. Nexus: apt mirror, raw binary, docker registry (패키지 미러링)

### 폐쇄망 전환

Nexus 미러링 완료 후 pfSense VLAN 30 룰 변경

- allow-all 제거
- 허용: VLAN 30 내부 상호 통신, 관리망(192.168.34.x) SSH, Nexus 접근, K8s 포트

### 폐쇄망 단계

Nexus 내부 미러에서 패키지 및 바이너리 설치

10. K8s
11. CICD: Gitea + act_runner (Terraform/Ansible 자동화, Nexus 미러링)
12. 웹앱 서비스 CI/CD (K8s 내부): GitLab + ArgoCD
13. DB

## ansible 명령어

- 쿠버네티스 배포

```ansible
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/k8s.yml
```
