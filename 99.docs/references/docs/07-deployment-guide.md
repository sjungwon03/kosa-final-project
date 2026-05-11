# 배포 가이드

## 1. 로컬 개발 환경

### 1.1 Docker Compose

```bash
# 전체 시스템 실행
docker-compose up -d

# 서비스 확인
docker-compose ps

# 로그 확인
docker-compose logs api-gateway

# 종료
docker-compose down
```

### 1.2 접속 정보
- Frontend: http://localhost:3000
- API Gateway: http://localhost:8000
- Employee Service: http://localhost:8001
- Welfare Service: http://localhost:8002
- MySQL: localhost:3306
- Redis: localhost:6379

## 2. 온프레미스 Kubernetes 배포

### 2.1 K8s Manifests 사용

```bash
# 네임스페이스 생성
kubectl create namespace kosa

# MySQL 배포
kubectl apply -f kubernetes/mysql/mysql.yaml

# Redis 배포
kubectl apply -f kubernetes/backend/redis.yaml

# 백엔드 서비스 배포
kubectl apply -f kubernetes/backend/employee-service.yaml
kubectl apply -f kubernetes/backend/welfare-service.yaml
kubectl apply -f kubernetes/backend/api-gateway.yaml

# 상태 확인
kubectl get pods -n kosa
```

### 2.2 Helm Chart 사용

```bash
# 온프레미스 배포
helm upgrade --install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --create-namespace \
  --values ./helm-charts/kosa-stack/values-onprem.yaml

# 상태 확인
helm list -n kosa
kubectl get all -n kosa
```

## 3. AWS EKS 배포

### 3.1 Terraform으로 인프라 생성

```bash
cd infrastructure/aws

# Terraform 초기화
terraform init

# Plan 확인
terraform plan

# Apply 실행 (VPN 포함)
terraform apply

# EKS kubeconfig 업데이트
aws eks update-kubeconfig --name kosa-eks --region ap-northeast-2

# VPN 연결 확인
aws vpn describe-vpn-connections --vpn-connection-ids <vpn-id>
```

### 3.2 VPN으로 온프레미스 DB 연결

```bash
# VPN Gateway 설정 확인
kubectl run -it --rm ping-test --image=busybox --restart=Never -- \
  ping 10.0.3.10  # 온프레미스 MySQL Master

# DB 연결 테스트
kubectl run -it --rm mysql-test --image=mysql:8.0 --restart=Never -- \
  mysql -h 10.0.3.10 -u root -p
```

### 3.3 Helm으로 앱 배포

```bash
# AWS 배포 (VPN DB 사용)
helm upgrade --install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --create-namespace \
  --values ./helm-charts/kosa-stack/values-aws.yaml \
  --set externalServices.mysql.host=10.0.3.10

# 상태 확인
kubectl get pods -n kosa --context=aws-cluster
```

## 4. 멀티클러스터 배포

### 4.1 Federation 설정

```bash
# Federation 리소스 생성
kubectl apply -f kubernetes-multicluster/federation.yaml

# Service Export/Import 생성
kubectl apply -f helm-charts/kosa-stack/templates/service-export.yaml
kubectl apply -f helm-charts/kosa-stack/templates/service-import.yaml
```

### 4.2 클라우드 버스팅 트리거

```bash
# 트리거 Job 생성
kubectl apply -f kubernetes-multicluster/cloudburst-trigger.yaml

# 로그 확인
kubectl logs job/cloudburst-trigger -n kosa
```

### 4.3 전체 배포 스크립트

```bash
# 멀티클러스터 배포
./deploy-multicluster.sh

# AWS 인프라만 배포
./deploy-aws.sh
```

## 5. Proxmox VM 배포

### 5.1 Terraform으로 VM 생성

```bash
cd infrastructure/proxmox

# Terraform 초기화
terraform init

# Plan 확인
terraform plan

# Apply 실행
terraform apply

# VM 정보 확인
terraform output
```

### 5.2 VM 접속

```bash
# SSH 접속
ssh root@10.0.2.10  # Master 1

# K8s 설치 확인
kubectl get nodes
```

## 6. Frontend S3 배포

### 6.1 빌드 및 배포

```bash
cd frontend

# 빌드
npm run build

# S3 배포
aws s3 sync out/ s3://kosa-frontend-bucket --delete

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id XXXXX \
  --paths "/*"
```

### 6.2 배포 스크립트

```bash
# S3 배포 스크립트 실행
./deploy-s3.sh
```

## 7. 모니터링

### 7.1 CloudWatch Dashboard

```bash
# Dashboard 확인
aws cloudwatch get-dashboard --dashboard-name kosa-dashboard
```

### 7.2 Logs

```bash
# EKS 로그
kubectl logs -f deployment/api-gateway -n kosa

# CloudWatch Logs
aws logs get-log-events \
  --log-group-name /aws/eks/kosa-eks/kosa \
  --log-stream-name api-gateway
```

## 8. 문제 해결

### 8.1 Pod Pending

```bash
# Pod 상태 확인
kubectl describe pod api-gateway-xxx -n kosa

# Node 리소스 확인
kubectl describe nodes

# AWS로 확장
kubectl scale deployment api-gateway --replicas=10 --context=aws-cluster
```

### 8.2 DB 연결 실패

```bash
# MySQL 서비스 확인
kubectl get svc mysql-master -n kosa

# DNS 확인
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup mysql-master.kosa.svc.cluster.local
```

### 8.3 Ingress 문제

```bash
# Ingress 확인
kubectl describe ingress kosa-ingress -n kosa

# Ingress Controller logs
kubectl logs -n ingress-nginx deployment/nginx-ingress-controller
```