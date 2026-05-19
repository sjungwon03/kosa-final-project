# 클라우드 버스팅 업데이트

## 아키텍처

```
┌────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                   │
│                                                                     │
│  ┌──────────────┐                                                  │
│  │  Route53     │  proxy.domain.com                               │
│  │  (DNS)       │       ↓                                          │
│  └──────────────┘                                                  │
│         │                                                           │
│         ↓                                                           │
│  ┌──────────────┐                                                  │
│  │  NLB         │  TCP 80/443                                      │
│  └──────────────┘                                                  │
│         │                                                           │
│         ↓                                                           │
│  ┌──────────────┐    ┌──────────────┐                             │
│  │  HAProxy #1  │    │  HAProxy #2  │                             │
│  │  (ACL Based) │────│  (ACL Based) │                             │
│  │  Routing)    │    │  Routing)    │                             │
│  └──────────────┘    └──────────────┘                             │
│         │                    │                                      │
│         ├────────────────────┼──────────────────────┐              │
│         │                    │                      │              │
│         ↓                    ↓                      ↓              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐         │
│  │  VPN Server  │    │              │    │  EKS Cluster  │         │
│  │  (WireGuard) │    │              │    │  + Karpenter  │         │
│  └──────────────┘    │              │    │              │         │
│         │            │              │    │  NLB Ingress  │         │
│         │            │              │    └──────────────┘         │
└─────────┼────────────┼──────────────┼──────────────────────────────┘
          │            │              │
          ↓            │              │
┌─────────────────────┼──────────────┼──────────────────────────────┐
│   On-Premises       │              │                              │
│                     │              │                              │
│  ┌──────────────┐  │  ┌──────────┐ │  ┌──────────────┐           │
│  │ Prometheus   │──┼─→│  App     │ │  │  Monitoring  │           │
│  │ (Metrics)    │  │  │  Servers │ │  │  (CPU 80%)   │           │
│  └──────────────┘  │  └──────────┘ │  └──────────────┘           │
│                     │              │                              │
│  ┌──────────────────┼──────────────┼──────────────────────────┐  │
│  │ Cloudburst Logic │              │                          │  │
│  │                  │              │                          │  │
│  │ if CPU > 80%:    │              │                          │  │
│  │   → EKS Active   │              │                          │  │
│  │ else:            │              │                          │  │
│  │   → On-Prem Only │              │                          │  │
│  └──────────────────┼──────────────┼──────────────────────────┘  │
│                     │              │                              │
└─────────────────────┼──────────────┼──────────────────────────────┘
                      │              │
                      │              │
          VPN Tunnel  │              │  Direct AWS Route
          (WireGuard) │              │  (EKS NLB IP)
                      │              │
```

## 트래픽 라우팅 로직

### 정상 상태 (CPU < 80%)
```
Route53 → NLB → HAProxy → ACL(inactive) → onprem_backend
                                   ↓
                            VPN Tunnel → On-Prem App
```

### 클라우드 버스팅 상태 (CPU ≥ 80%)
```
Route53 → NLB → HAProxy → ACL(active) → eks_backend
                                   ↓
                            AWS NLB → EKS Pod
```

## HAProxy ACL 기반 라우팅

```ini
frontend http_front
    bind *:80
    mode tcp
    
    acl cloudburst_active acl_file(cloudburst_active.txt)
    
    use_backend eks_http if cloudburst_active
    default_backend onprem_http
```

## 구성 요소

### AWS
| 리소스 | 설명 |
|---------|------|
| EKS | Kubernetes 클러스터 (K8s 1.28) |
| Karpenter | Node Auto-scaler |
| NLB | HAProxy용 |
| EKS NLB | Ingress용 (cloudburst 트래픽) |
| HAProxy EC2 | 트래픽 라우터 |
| VPN EC2 | WireGuard 서버 |

### 온프렘
| 리소스 | 설명 |
|---------|------|
| Prometheus | CPU 메트릭 수집 |
| App Servers | 웹 애플리케이션 |
| MetalLB | Ingress IP |

## 배포 가이드

### 1. Terraform 배포

```bash
./deploy-aws.sh
```

### 2. EKS 설정

```bash
# kubeconfig
aws eks update-kubeconfig --name kosa-proxy-eks --region ap-northeast-2

# Karpenter 배포
CLUSTER_NAME=kosa-proxy-eks
IMAGE_REGISTRY=harbor.your-domain.com
envsubst < 02.terraform/modules/aws/karpenter/templates/karpenter-provisioner.yaml.tpl | kubectl apply -f -
```

### 3. EKS Ingress LB IP 확인

```bash
kubectl get svc api-gateway -n kosa
# EXTERNAL-IP를 vault_eks_ingress_ip에 설정
```

### 4. HAProxy 배포

```bash
cd 03.ansible/workspace
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_haproxy
```

### 5. Cloudburst 테스트

```bash
# HAProxy EC2에서 실행
ssh -i kosa-proxy-key.pem ec2-user@<HAProxy_IP>

# 상태 확인
cloudburst-control.sh status

# 수동 활성화 (테스트)
cloudburst-control.sh enable

# 수동 비활성화
cloudburst-control.sh disable

# CPU 기반 자동 체크
cloudburst-control.sh check
```

## Cloudburst 제어 스크립트

**/usr/local/bin/cloudburst-control.sh**

```bash
# Prometheus에서 온프렘 CPU 메트릭 조회
curl -s "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode 'query=avg(rate(container_cpu_usage_seconds_total{namespace="kosa"}[5m])) / avg(container_spec_cpu_quota{namespace="kosa"} / container_spec_cpu_period{namespace="kosa"}) * 100'

# CPU ≥ 80% → ACL 활성화 → EKS backend 사용
# CPU < 80%  → ACL 비활성화 → onprem backend 사용
```

## Karpenter 동작

```
트래픽 증가 → HAProxy → EKS NLB → Pending Pods
                            ↓
                    Karpenter Provisioner
                            ↓
                    EC2 Node 생성 (t3.micro/small/medium)
                            ↓
                    Pods 실행 → 서비스
                            ↓
    트래픽 감소 → Node Consolidation → EC2 삭제
```

## Cron 설정 (자동 모니터링)

```bash
# HAProxy EC2에서
crontab -e

# 5분마다 CPU 체크
*/5 * * * * /usr/local/bin/cloudburst-control.sh check >> /var/log/cloudburst.log 2>&1
```

## 비용 (Cloudburst)

| 리소스 | 정상 | 버스팅 |
|---------|------|--------|
| HAProxy EC2 | ~$15/월 | ~$15/월 |
| VPN EC2 | ~$15/월 | ~$15/월 |
| EKS Control Plane | ~$73/월 | ~$73/월 |
| EKS Nodes (t3.micro) | $0 | ~$10-30/월 |
| NLB | ~$18/월 | ~$36/월 (2개) |

**정상:** ~$120/월
**버스팅:** ~$150-200/월 (부하 시, t3.micro 사용)

### Free Tier 적용
- t3.micro: Free Tier (12개월, 750시간/월)
- t3.small: ~$15/월
- t3.medium: ~$30/월

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