# KOSA 최종프로젝트 - 4팀

## 프로젝트 개요

온프레미스 인프라 기반의 사원 관리 및 복지포인트몰 시스템을 AWS 클라우드 버스팅으로 확장하는 하이브리드 클라우드 구축 프로젝트입니다.

### 목적

- 온프레미스 리소스 부하 시 AWS 클라우드 자동 확장 (Cloud Bursting)
- HAProxy + WireGuard VPN으로 온프레미스 ↔ AWS 연결
- EKS + Karpenter로 AWS K8s 클러스터 자동 관리
- Route53 + NLB로 도메인 기반 트래픽 라우팅

### 구성 범위

| 구분              | 환경              | 구성                                                   |
| ----------------- | ----------------- | ------------------------------------------------------ |
| **On-Premises**   | Proxmox           | K8s Cluster, Percona XtraDB Cluster, Redis, Prometheus |
| **AWS Cloud**     | EKS + EC2         | HAProxy, VPN, EKS, Karpenter, NLB                      |
| **트래픽 라우팅** | Route53 + HAProxy | ACL 기반 클라우드 버스팅                               |

---

## 레포지터리 구조

```
├── 00.scripts/         # Proxmox 베이스 템플릿 생성 스크립트
├── 01.packer/          # 공통 VM 템플릿 이미지 빌드
├── 02.terraform/       # 인프라 프로비저닝 (Proxmox + AWS)
│   ├── modules/aws/    # AWS 모듈 (VPC, EC2, EKS, NLB, Route53, VPN, Karpenter)
│   └── env/aws/        # AWS 배포 환경
├── 03.ansible/         # OS 설정 및 서비스 오케스트레이션
│   └── workspace/
│       ├── roles/      # HAProxy, WireGuard, Prometheus
│       └── inventories/aws/
├── 04.k8s/             # Kubernetes 리소스 매니페스트
├── 05.cicd/            # Gitea + act_runner 인프라 CI
├── 06.argocd/          # ArgoCD GitOps CD
├── 70.security/        # 보안 관제 (Wazuh)
├── 80.monitoring/      # PLG 스택 (Prometheus, Loki, Grafana)
└── 99.docs/            # 프로젝트 산출물
    └── jungwon/        # AWS 클라우드 버스팅 문서
    └── hyeyun/         # pfSense, VPN 문서
```

---

## 아키텍처

### 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                                   │
│                                                                      │
│  Route53 (DNS) → NLB → HAProxy (ACL Routing) → EKS + Karpenter       │
│                         ↓                                            │
│                    VPN Server (WireGuard)                            │
│                         ↓                                            │
└─────────────────────────┼───────────────────────────────────────────┘
                          │
                          │ WireGuard VPN Tunnel
                          │
┌─────────────────────────┼───────────────────────────────────────────┐
│                      On-Premises (Proxmox)                           │
│                                                                      │
│  pfSense → HAProxy → K8s Cluster → Percona XtraDB Cluster → Redis        │
│              ↓                                                       │
│         Prometheus (CPU Monitoring)                                 │
│              ↓                                                       │
│    CPU ≥ 80% → Cloud Burst Trigger → AWS EKS Active                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 클라우드 버스팅 동작

```
정상 상태 (CPU < 80%):
Route53 → NLB → HAProxy → VPN → On-Prem K8s

버스팅 상태 (CPU ≥ 80%):
Route53 → NLB → HAProxy → EKS NLB → AWS EKS Pods
                              ↓
                      Karpenter Auto-Scale (t3.micro)
```

---

## AWS 인프라 구성

| 리소스          | 타입           | 설명                                 |
| --------------- | -------------- | ------------------------------------ |
| **VPC**         | 10.0.0.0/16    | 2개 AZ Public Subnet                 |
| **HAProxy EC2** | t3.micro x 2   | 트래픽 라우터 + ACL 기반 분산        |
| **VPN EC2**     | t3.micro + EIP | WireGuard 서버                       |
| **EKS**         | K8s 1.28       | 클라우드 버스팅용 K8s                |
| **Karpenter**   | Auto-Scaler    | t3.micro/small/medium 노드 자동 생성 |
| **NLB**         | TCP 80/443     | HAProxy용 로드밸런서                 |
| **Route53**     | DNS            | 도메인 → NLB Alias                   |

### 비용 (Free Tier)

| 리소스               | 정상 상태 | 버스팅 상태 |
| -------------------- | --------- | ----------- |
| HAProxy EC2 x 2      | ~$15/월   | ~$15/월     |
| VPN EC2 + EIP        | ~$15/월   | ~$15/월     |
| EKS Control Plane    | ~$73/월   | ~$73/월     |
| EKS Nodes (t3.micro) | $0        | ~$10-30/월  |
| NLB x 2              | ~$36/월   | ~$36/월     |

**월 비용:** 정상 ~$120, 버스팅 ~$150-200

---

## 배포 가이드

### 1. Terraform 배포 (AWS 인프라)

```bash
# 변수 설정
cd 02.terraform/env/aws
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 배포
./deploy-aws.sh
```

### 2. VPN 설정

```bash
# 온프렘 WireGuard 키 생성
wg genkey | tee private.key | wg pubkey > public.key

# VPN 서버 배포
cd 03.ansible/workspace
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_vpn

# VPN Public Key 확인
ssh -i kosa-proxy-key.pem ec2-user@<VPN_IP> 'cat /etc/wireguard/public.key'
```

### 3. EKS 설정

```bash
# kubeconfig
aws eks update-kubeconfig --name kosa-proxy-eks --region ap-northeast-2

# Karpenter + 앱 배포
CLUSTER_NAME=kosa-proxy-eks
IMAGE_REGISTRY=harbor.your-domain.com
envsubst < 02.terraform/modules/aws/karpenter/templates/karpenter-provisioner.yaml.tpl | kubectl apply -f -
```

### 4. HAProxy 배포

```bash
# vault.yml 업데이트 (VPN Key, EKS IP)
vim inventories/aws/group_vars/vault.yml

# HAProxy 배포
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_haproxy

# Cloudburst Cron 설정
*/5 * * * * /usr/local/bin/cloudburst-control.sh check
```

---

## 클라우드 버스팅 제어

### HAProxy ACL 기반 라우팅

```ini
frontend http_front
    acl cloudburst_active acl_file(cloudburst_active.txt)
    use_backend eks_http if cloudburst_active
    default_backend onprem_http
```

### 제어 스크립트

```bash
# 상태 확인
cloudburst-control.sh status

# 수동 EKS 전환
cloudburst-control.sh enable

# 온프렘 복원
cloudburst-control.sh disable

# CPU 기반 자동 전환
cloudburst-control.sh check
```

---

## 모니터링

### Prometheus 메트릭

```yaml
- container_cpu_usage_seconds_total
- container_spec_cpu_quota
- container_spec_cpu_period
```

### HAProxy Stats

```
http://<HAProxy_IP>:8404/stats
```

### EKS Metrics

```bash
kubectl top pods -n kosa
kubectl top nodes
kubectl get pods -n kosa -w
```

---

## 인프라 설계 원칙

### 운영 및 자동화

- **수동 설치**: pfSense (GUI 설정 유리)
- **자동화**: K8s, EKS, HAProxy (IaC)

### 네트워크 및 보안

- VLAN 20/30 망 분리
- pfSense + HAProxy VIP로 공격 표면 최소화
- WireGuard VPN (AWS ↔ 온프렘)

### 가용성

- HAProxy Keepalived VIP (SPOF 제거)
- EKS Multi-AZ 배포
- Percona XtraDB Cluster (K8s Native HA)

---

## 의도적 트레이드오프

| 리소스          | 트레이드오프 | 이유                                 |
| --------------- | ------------ | ------------------------------------ |
| pfSense         | SPOF         | 네트워크 최전방, GUI 설정 유리       |
| Platform Worker | SPOF         | ArgoCD 파드만 구동, 서비스 중단 없음 |
| VPN EC2         | 단일         | Free Tier 제한, 향후 HA 구성 가능    |

---

## 문서

| 문서                | 위치                                         |
| ------------------- | -------------------------------------------- |
| AWS 클라우드 버스팅 | `99.docs/jungwon/04-aws-cloud-bursting.md`   |
| AWS VPN 연결        | `99.docs/jungwon/03-aws-cloud-vpn.md`        |
| Percona DB 배포     | `99.docs/jungwon/db/`                        |
| pfSense 설정        | `99.docs/hyeyun/reference/`                  |
| 전체 아키텍처       | `99.docs/references/docs/01-architecture.md` |

---

## SSH 연결

```bash
KEY=kosa-proxy-key.pem

# HAProxy
ssh -i $KEY ec2-user@<HAProxy_IP>

# VPN Server
ssh -i $KEY ec2-user@<VPN_IP>

# EKS
kubectl get nodes
```

---
