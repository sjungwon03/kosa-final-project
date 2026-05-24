# Proxmox 온프레미스 + AWS 클라우드 하이브리드 인프라 자동화 구현

- 이 저장소는 인프라 **구축 및 운영 가이드** (IaC, 런북, 구성 스크립트)를 관리함
- GitLab 파이프라인이 이 저장소를 참조하여 Terraform/Ansible을 자동 실행하는 **인프라 CI/CD 소스** 역할도 겸함

**주요 문서 링크**

- [가상 머신 명세 (VM-SPEC)](./VM-SPEC.md): 전체 노드 IP, 역할, 고가용성(HA) 배치 현황
- [아키텍처 설계 및 산출물](https://drive.google.com/drive/folders/1EEtL6_PlorKLy2FLwEeale6XOPjQs05w)

**목차**

- [온프레미스](#온프레미스)
  - [서비스 접근 아키텍처](#서비스-접근-아키텍처)
  - [인프라 설계 원칙](#인프라-설계-원칙)
  - [의도적 트레이드오프](#의도적-트레이드오프)
  - [구성 순서](#구성-순서)
- [클라우드](#클라우드)

**레포지터리 구조 및 CI/CD 분리 전략**

- 현재 단일 저장소(Monorepo) 내에 인프라 코드와 애플리케이션 코드가 공존함
- 이를 위해 GitLab 상에서 `Infra` 그룹과 `App` 그룹으로 분리하여 CI/CD 파이프라인 및 접근 권한을 완벽히 격리 운영함

**[영역 1] 인프라 프로비저닝 및 구성 관리 (Infra CI/CD)**

> 컨트롤 노드의 GitLab Runner가 담당하며, 아래 경로의 코드가 변경될 때만 파이프라인이 트리거됨

```bash
├── 00.proxmox/         # Proxmox 직접 구성 (ISO 기반 VM, pfSense 등)
├── 01.packer/          # 공통 VM 템플릿 이미지 빌드
├── 02.terraform/       # Proxmox VM 프로비저닝 (IaC)
├── 03.ansible/         # OS 설정 및 K8s, DNS, Vault 등 서비스 오케스트레이션
```

**[영역 2] 애플리케이션 배포 및 K8s 리소스 (App CI/CD)**

> K8s 내부의 Runner와 ArgoCD가 담당하며, 앱 배포 파일이 변경될 때만 파이프라인이 트리거됨

```bash
├── 04.k8s/             # Kubernetes 리소스 매니페스트 (YAML), 앱 배포 파일
├── 05.cicd/            # CI/CD 지원 도구 (Nexus 미러링 등)
├── 06.monitoring/      # 관측성 스택 (PLG)
├── 07.stress/          # 부하/이벤트 생성
├── 08.siem/            # 보안 관제 (Wazuh SIEM)
└── 09.cloud/           # AWS 클라우드 확장 (VPC, ALB)
```

## 온프레미스

### 서비스 접근 아키텍처

**외부 접속 및 트래픽 흐름**

- 공인 IP 미보유로 AWS EC2를 엣지로 사용
- 외부 사용자 → 도메인(EC2 공인 IP) → EC2 Nginx → WireGuard VPN (pfSense) → HAProxy VIP → 내부 서비스
- HAProxy L7 라우팅: HTTP Host 헤더(도메인) 기반으로 서비스 분기 (Nexus, K8s 클러스터, Vault 등)

```text
+-----------------------+
|     External User     |
+-----------+-----------+
            │ DNS (도메인: EC2 공인 IP)
            ▼
+-----------------------+
|   AWS EC2 (Nginx)     | (공인 IP, 리버스 프록시)
+-----------+-----------+
            │ WireGuard VPN 터널
            ▼
+-----------+-----------+
|        pfSense        |
+-----------+-----------+
            │
            ▼
+-----------+-----------+
|        HAProxy        | (VIP: 172.16.20.25)
+-----------+-----------+
            │
            ├─ [ Nexus ]
            ├─ [ K8s Cluster ] (GitLab, Harbor, 웹앱 등)
            └─ [ Vault / Monitoring ]
```

**CI/CD 파이프라인 흐름 및 이중화 아키텍처**

- **메인 파이프라인 (GitLab VM)**: 독립된 가상 서버(`cicd-01`)에 GitLab을 호스팅하여 인프라/앱 배포 중앙 통제
  - **동작 방식**: 엔지니어의 코드 Push, 또는 Prometheus 부하 감지 알람(Webhook) 발생 시 GitLab Runner가 트리거되어 Terraform/Ansible 자동 실행
- **장애 대비 백업 파이프라인 (Gitea)**: K8s 클러스터 내부에 경량화된 Gitea 인스턴스 구성
  - **동작 방식**: 메인 GitLab 서버 장애 시, Gitea를 우회 경로로 사용하여 인프라 배포 및 ArgoCD 연동 앱 배포가 멈추지 않도록 단일 장애점(SPOF) 제거

```text
[메인 파이프라인]                       [백업 파이프라인]
GitLab (cicd-01 VM)                     Gitea (K8s 내부)
      │                                         │
      ├─► Push 트리거 (코드 반영)               ├─► GitLab 장애 시 우회
      └─► Alert 트리거 (부하 알람)              │   (단일 장애점 제거)
      ▼                                         ▼
GitLab Runner                           ArgoCD / Runner
      │                                         │
      ├── Terraform (인프라 배포)              └── K8s 애플리케이션 배포
      └── Ansible (OS 및 K8s Join)
```

### 인프라 설계 원칙

**운영 및 자동화 전략**

- 수동 설치: 구조 변화가 적고 GUI 설정이 유리한 도구 (ex. pfSense)
- 자동화: 설정이 잦고 스케일링이 필요한 서비스 (ex. K8s)

**네트워크 및 보안**

- 보안 컴플라이언스 준수를 위한 물리/논리적 망 분리 (VLAN 20/30)
- 인프라 제약 시 유연한 대응이 가능한 아이피 체계 구축 (단일망 전환 가능)
- 모든 외부 인입은 pfSense와 HAProxy VIP로 제한하여 공격 표면 최소화

**가용성 및 서비스 연속성**

- 단일 장애점(SPOF) 제거를 위한 노드 분산 배치 및 VIP(Keepalived) 도입
- 관리 서비스 독립성: CICD, Vault, MinIO를 K8s 외부에 구성하여 순환 의존성(Ouroboros) 방지
- 스토리지 이원화: 제어부(Local-LVM)와 데이터부(RBD) 분리로 안정성 및 확장성 확보

> 우로보로스(Ouroboros): A를 고치기 위해 B가 필요한데, B가 작동하려면 A가 살아있어야 하는 상황

### 의도적 트레이드오프

**사전 구성 의존 인프라 (프로젝트 범위 외)**

- Ceph 클러스터(rbd-storage): Proxmox 호스트에 사전 구성됨
- 이 프로젝트는 Ceph를 소비만 함

**pfSense (SPOF)**

- 네트워크의 최전방 접점으로서 단일 구성됨 (향후 필요시 HA 구성 고려)

**K8s Platform Worker (SPOF)**

- ArgoCD 등 인프라 지원용 파드만 구동되므로 일시적 장애가 실제 서비스 중단을 초래하지 않음

- ArgoCD 등 인프라 지원용 파드만 구동되므로 일시적 장애가 실제 서비스 중단을 초래하지 않음

### 구성 순서

#### 인터넷 연결 단계

인터넷 접근이 가능한 상태에서 진행 (VLAN 30 allow-all 상태)

1. pfSense: 방화벽, NAT, WireGuard VPN (수동 설치)
2. Control: Terraform, Ansible 컨트롤 노드 (수동 설치)
3. DNS: CoreDNS, etcd, Keepalived VIP
4. MinIO: Terraform state backend
5. SIEM: Wazuh manager // 템플릿에 에이전트가 존재
6. Monitor: PLG 스택, Keepalived VIP (promtail 로그 수집) // 템플릿에 존재
7. Vault: HashiCorp Vault HA (서비스 시크릿 관리)
8. HAProxy: L4 로드밸런서, Keepalived VIP
9. AWS EC2: Nginx 리버스 프록시, WireGuard 터널 연결 (pfSense)
10. Nexus: apt mirror, raw binary, 컨테이너 이미지 레지스트리

#### 폐쇄망 전환 (설계 기준)

- Nexus 미러링 완료 후 pfSense 방화벽에서 외부망 연결(allow-all) 룰을 제거하여 독자 생존 환경으로 전환함
- 방화벽 허용 룰: VLAN 30 내부 상호 통신, 관리망(192.168.34.x) SSH, 내부 Nexus 접근, K8s 포트

#### 폐쇄망 격리 후 후속 구성

외부망 없이 내부 Nexus 미러를 통해 패키지 및 바이너리 설치 진행

11. K8s
12. CI/CD 배포 시스템
13. Stress/Test

> **[참고] 폐쇄망 실증 한계**: 아키텍처 상 내부 미러링 및 오프라인 배포 경로가 설계되어 있으나, 실제 운영 환경처럼 외부 인터넷을 완전히 차단한 상태에서의 End-to-End 파이프라인 구동 테스트는 아직 진행되지 않았음

---

## [TODO] 향후 아키텍처 고도화 로드맵

> 인프라 확장성 및 운영 한계를 극복하기 위한 향후 시스템 리팩토링 계획

### Phase 1: CI/CD 파이프라인 성능 및 확장성 고도화

- **GitLab Runner 스케일 아웃**: 인프라 코드 및 컨테이너 빌드 증가에 따른 단일 VM(`cicd-01`) 병목 해소. K8s 내부 Pod(K8s Executor)로 빌드 작업을 동적 분산시키거나 Runner VM 자동 증설 아키텍처 도입 (상세 내용 `09.cicd.md` 참조)
- **GitOps 연동 노드 자동 프로비저닝**: 관리자의 코드 Push를 감지하여 Terraform과 Ansible을 자동 실행하고 K8s 워커 노드를 동적으로 증설 및 조인(Join)하는 완전 자동화 파이프라인 구축

### Phase 2: 트래픽 레이어 추상화 및 분산

- **L4/L7 라우팅 역할 분리**: 단일 HAProxy VIP에 집중된 트래픽 진입점 분산. K8s 기반 웹앱 서비스 트래픽은 전용 Ingress Controller(Nginx 등)로 위임하여 아키텍처 추상화
- **서비스 메시(Service Mesh) 도입**: 단일 로드밸런서를 통한 남북(North-South) 트래픽 제어를 넘어, Istio 등을 활용해 클러스터 내부(East-West) 마이크로서비스 간 트래픽 라우팅 및 mTLS 통신 제어 구조 마련

### Phase 3: 인프라 감사(Audit) 및 네트워크 가시성 확보

- **배포 실행자 추적(Deployer Tracking)**: 현재 Ansible 실행 이력이 컨트롤 노드의 `control` 계정으로만 단일 식별되는 한계를 개선. GitLab 파이프라인 연동 시 주입되는 환경변수(`$GITLAB_USER_LOGIN` 등)를 인프라 배포 로그 및 Auditd에 기록하여, "누가, 언제, 어떤 코드로" 인프라를 변경했는지 완벽한 추적성(Audit Trail) 확보
- **차세대 CNI 및 가시성 확보**: 운영(Prod) 환경의 K8s 네트워크 플러그인을 eBPF 기반의 Cilium으로 전환. 컨테이너 간 트래픽 가시성(Hubble) 확보 및 미세 분절화(Micro-segmentation) 제어

---

## 클라우드

**목적**

- 온프레미스 서비스 중 트래픽 과부하 시 클라우드로 자동 확장 (cloud bursting)
- 오토스케일링 데모: 부하 기반 EC2 인스턴스 자동 증감 (ASG + ALB)

> [미확정] 온프렘과 단일 서비스로 통합할지 서브 도메인으로 분리할지 결정 필요

> EKS 미사용: on-prem K8s와 역할 중복, 컨트롤 플레인 고정 비용($0.10/h) 대비 실증 효과 낮음

**아키텍처**

```text
+-----------------------+
|     External User     |
+-----------+-----------+
            │ Route53 (도메인: ALB DNS)
            ▼
+-------------------------------+
|   AWS ALB (ap-northeast-2)    |
+-------------------------------+
            │
            ▼
+-------------------------------+
|   EC2 Auto Scaling Group      |
|   (Web App: t3.micro × 1~3)  |
|   CPU 70% 초과 → scale out    |
+-------------------------------+
            │ WireGuard VPN (on-prem 백엔드 연동, 선택)
            ▼
+-------------------------------+
|   HAProxy VIP (172.16.20.25)  |
+-------------------------------+
```

**EC2 구성 (Terraform)**

- 리전: ap-northeast-2 (서울)
- VPC: 10.0.0.0/16 / Public Subnet 2개 (AZ: 2a, 2c)
- ALB → Target Group (HTTP:80) → ASG
- Launch Template: Ubuntu 22.04 LTS, t3.micro, userdata 앱 기동
- Auto Scaling: min 1 / max 3 / desired 1, CPU 기반 스케일링 정책

> [TODO] 확정 후 업데이트 필요

---

> 본 프로젝트는 LLM(AI Pair Programmer)을 사용하여 인프라 리서치 및 설계 검증 도구로 활용함
