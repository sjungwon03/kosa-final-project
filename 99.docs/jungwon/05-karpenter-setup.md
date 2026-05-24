# Karpenter Setup Guide

## 개요

Karpenter는 AWS EKS용 오픈소스 노드 자동 스케일러다. 클러스터 내 Pod의 리소스 요청을 기반으로 EC2 인스턴스를 자동 생성/삭제한다.

### Cluster Autoscaler vs Karpenter

| 특징 | Cluster Autoscaler | Karpenter |
|------|--------------------|-----------|
| 스케일링 속도 | ~2분 | ~30초 |
| 인스턴스 선택 | ASG 기반 | Pod 요청 기반 (더 정확) |
| 비용 최적화 | ASG 크기 고정 | On-demand/Spot 자동 선택 |
| Consolidation | 수동 | 자동 (불필요 노드 삭제) |

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                         EKS Cluster                              │
│                                                                  │
│  ┌──────────────┐                                               │
│  │  Karpenter   │  Pod Pending 감지 → 노드 생성                 │
│  │  Controller  │                                               │
│  └──────────────┘                                               │
│         │                                                        │
│         ↓                                                        │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  Provisioner │    │AWSNodeTemplate│    │   Pod Specs   │      │
│  │  (요구사항)   │───→│  (AWS 설정)   │───→│ (CPU/Memory) │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                    │                    │             │
│         └────────────────────┴────────────────────┘             │
│                              ↓                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    EC2 Instances                          │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │  │
│  │  │t3.micro │  │t3.small │  │t3a.small│  │ Spot     │     │  │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Resources                               │
│                                                                  │
│  • VPC Subnets (karpenter.sh/discovery tag)                     │
│  • Security Groups (karpenter.sh/discovery tag)                 │
│  • IAM Instance Profile                                         │
│  • EKS Access Entry                                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Terraform 구성

### IAM Role

```hcl
resource "aws_iam_role" "karpenter" {
  name = "${var.cluster_name}-karpenter"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}
```

### Required Policies

| Policy | 설명 |
|---------|------|
| AmazonEKSClusterPolicy | EKS 클러스터 접근 |
| AmazonEKSWorkerNodePolicy | EKS 노드 권한 |
| AmazonEC2ContainerRegistryReadOnly | ECR 이미지 pull |
| AmazonSSMManagedInstanceCore | SSM Session Manager 접근 |

### Instance Profile

```hcl
resource "aws_iam_instance_profile" "karpenter" {
  name = "${var.cluster_name}-karpenter"
  role = aws_iam_role.karpenter.name
}
```

### Subnet & Security Group Tagging

Karpenter가 노드를 생성할 위치를 찾기 위해 태깅 필요:

```hcl
resource "aws_ec2_tag" "subnet" {
  resource_id = var.subnet_ids[count.index]
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "security_group" {
  resource_id = var.security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
```

### EKS Access Entry

```hcl
resource "aws_eks_access_entry" "karpenter" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.karpenter.arn
  type          = "EC2_LINUX"
}
```

## Karpenter Provisioner

### YAML 구성

```yaml
apiVersion: karpenter.sh/v1beta1
kind: Provisioner
metadata:
  name: cloudburst
spec:
  requirements:
    - key: karpenter.k8s.aws/instance-family
      operator: In
      values: ["t3", "t3a", "t2"]
    - key: karpenter.k8s.aws/instance-size
      operator: In
      values: ["micro", "small", "medium"]
    - key: topology.kubernetes.io/zone
      operator: In
      values: ["ap-northeast-2a", "ap-northeast-2b"]
    - key: kubernetes.io/arch
      operator: In
      values: ["amd64"]
  
  limits:
    resources:
      cpu: 100
      memory: 100Gi
  
  consolidation:
    enabled: true
  
  ttlSecondsAfterEmpty: 30
  ttlSecondsUntilExpired: 2592000
```

### Requirements 설명

| Requirement | 설명 |
|-------------|------|
| instance-family | t3, t3a, t2 (저비용 인스턴스) |
| instance-size | micro, small, medium |
| zone | ap-northeast-2a, ap-northeast-2b |
| arch | amd64 |

### Consolidation

**Consolidation이 활성화되면:**
- 불필요한 노드 자동 삭제
- 비용 최적화
- 노드利用率最大化

### TTL (Time To Live)

| TTL | 설명 |
|-----|------|
| ttlSecondsAfterEmpty | 30초 (노드 비어있으면 삭제) |
| ttlSecondsUntilExpired | 30일 (노드 교체) |

## AWSNodeTemplate

```yaml
apiVersion: karpenter.k8s.aws/v1beta1
kind: AWSNodeTemplate
metadata:
  name: cloudburst-provider
spec:
  subnetSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
  
  securityGroupSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
  
  amiSelector:
    aws-eks/managed: "true"
  
  tags:
    karpenter.sh/discovery: ${CLUSTER_NAME}
    Purpose: cloudburst
```

## 배포 가이드

### 1. Terraform 배포

```bash
cd 02.terraform/env/aws
terraform apply
```

### 2. Karpenter Helm 설치

```bash
helm repo add karpenter https://charts.karpenter.sh
helm repo update

helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --create-namespace \
  --set serviceAccount.annotations.eks.amazonaws.com/role-arn=arn:aws:iam::945503455708:role/kosa-proxy-eks-karpenter \
  --set settings.clusterName=kosa-proxy-eks \
  --set settings.clusterEndpoint=https://3792F335CBA16D15DA5BE729A782F7AF.sk1.ap-northeast-2.eks.amazonaws.com \
  --set settings.interruptRate=5m \
  --wait
```

### 3. Provisioner 배포

```bash
CLUSTER_NAME=kosa-proxy-eks
IMAGE_REGISTRY=harbor.hyeyunjeong.shop

envsubst < 02.terraform/modules/aws/karpenter/templates/karpenter-provisioner.yaml.tpl | kubectl apply -f -
```

### 4. 확인

```bash
kubectl get pods -n karpenter
kubectl get provisioner
kubectl get awsnodetemplate
```

## 동작 테스트

### Pod 배포

```bash
kubectl scale deployment api-gateway -n kosa --replicas=3
```

### 노드 생성 확인

```bash
kubectl get nodes -w
kubectl describe nodes
```

### Karpenter 로그

```bash
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

## 비용 최적화

### Spot Instance 사용

```yaml
requirements:
  - key: karpenter.k8s.aws/capacity-type
    operator: In
    values: ["spot", "on-demand"]
```

### Spot Instance 비용

| Instance | On-Demand | Spot (60% 할인) |
|----------|-----------|-----------------|
| t3.micro | $0.0116/h | ~$0.0046/h |
| t3.small | $0.023/h | ~$0.0092/h |
| t3.medium | $0.0464/h | ~$0.0186/h |

### Free Tier vs Spot

- **Free Tier**: 12개월, 750시간/월 (t3.micro)
- **Spot**: 무제한, ~60% 할인

### 비용 예상

| 상태 | 노드 | 비용/월 |
|------|------|--------|
| Idle | 0 | $0 |
| Low Load | 2 t3.micro | ~$17 |
| High Load | 4 t3.small | ~$67 |
| Spot 사용 | 4 t3.small | ~$27 |

## 모니터링

### 메트릭

```bash
kubectl top nodes
kubectl top pods -n kosa
kubectl get pods -n karpenter
```

### Events

```bash
kubectl get events -n karpenter --sort-by='.lastTimestamp'
kubectl describe provisioner cloudburst
```

### Prometheus

```yaml
- karpenter_nodes_created_total
- karpenter_nodes_deleted_total
- karpenter_pods_pending_total
```

## 문제 해결

### Pod Pending

```bash
kubectl describe pod <pod-name> -n kosa
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

### 노드 생성 실패

1. IAM Role 확인
```bash
aws iam get-role --role-name kosa-proxy-eks-karpenter
```

2. Subnet/SG Tag 확인
```bash
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=kosa-proxy-eks"
aws ec2 describe-security-groups --filters "Name=tag:karpenter.sh/discovery,Values=kosa-proxy-eks"
```

### 노드 삭제 안 됨

```bash
kubectl describe node <node-name>
kubectl get pods -A -o wide | grep <node-name>
```

Consolidation은 모든 Pod가 다른 노드로 이동 가능해야 삭제함.

## 클라우드 버스팅 연동

### 동작 시나리오

```
온프렘 CPU ≥ 80% → HAProxy ACL 활성화 → EKS NLB → 트래픽 증가
                                                    ↓
                                            Pod Pending 증가
                                                    ↓
                                            Karpenter 노드 생성
                                                    ↓
                                            Pod 실행 → 서비스
                                                    ↓
            트래픽 감소 → Pod 삭제 → 노드 Empty → Consolidation → 노드 삭제
```

### Cloudburst Provisioner

```yaml
spec:
  limits:
    resources:
      cpu: 100        # 최대 100 CPU cores
      memory: 100Gi   # 최대 100Gi memory
  
  consolidation:
    enabled: true     # 자동 노드 삭제
  
  ttlSecondsAfterEmpty: 30  # 빈 노드 30초 후 삭제
```

## 참고

- [Karpenter Docs](https://karpenter.sh/)
- [AWS EKS Karpenter](https://docs.aws.amazon.com/eks/latest/userguide/karpenter.html)
- [Karpenter GitHub](https://github.com/aws/karpenter)