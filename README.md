# KOSA 최종프로젝트 - 4팀

- [TODO] 프로젝트 개요 작성 필요 (목적, 구성 범위, 팀 역할 등)

**레포지터리 구조**
```bash
├── 00.scripts/         # Proxmox 베이스 템플릿 생성 스크립트
├── 01.packer/          # 공통 VM 템플릿 이미지 빌드
├── 02.terraform/       # Proxmox VM 프로비저닝 (IaC)
├── 03.ansible/         # OS 설정 및 서비스 오케스트레이션
├── 03-1.nexus/         # 폐쇄망 전환 전 Nexus 미러링 체크리스트
├── 04.k8s/             # Kubernetes 리소스 매니페스트 (YAML)
├── 05.cicd/            # GitHub Actions 기반 파이프라인 자동화
├── 06.argocd/          # GitOps 배포 환경 구성
├── 70.security/        # 보안 관제 및 에이전트 설정 (Wazuh)
├── 80.monitoring/      # 관측성 스택 구축 (PLG)
└── 99.docs/            # 프로젝트 통합 산출물 및 매뉴얼
```


## 구성 순서

### 인터넷 연결 단계
인터넷 접근이 가능한 상태에서 진행 (VLAN 30 allow-all 상태)

1. pfSense: 방화벽, NAT, WireGuard VPN (수동)
2. Control: Terraform, Ansible 컨트롤 노드 (스크립트)
3. MinIO: Terraform state backend
4. DNS: CoreDNS, etcd, Keepalived VIP
5. HAProxy: L4 로드밸런서, Keepalived VIP
6. Nexus: apt mirror, raw binary, docker registry (패키지 미러링 완료)

### 폐쇄망 전환
Nexus 미러링 완료 후 pfSense VLAN 30 룰 변경
- allow-all 제거
- 허용: VLAN 30 내부 상호 통신, 관리망(192.168.34.x) SSH, Nexus 접근, K8s 포트

### 폐쇄망 단계
Nexus 내부 미러에서 패키지 및 바이너리 설치

7. K8s
8. CICD
9. DB
10. Vault
11. SIEM
12. Monitor
