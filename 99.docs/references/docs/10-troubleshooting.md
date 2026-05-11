# 문제 해결 (Troubleshooting)

## 1. Docker Compose 문제

### 1.1 MySQL Connection Failed

**오류**:
```
Can't connect to MySQL server on 'localhost'
```

**해결**:
```bash
# MySQL 상태 확인
docker-compose ps mysql

# MySQL 로그 확인
docker-compose logs mysql

# MySQL 재시작
docker-compose restart mysql

# DB 초기화
./init-db.sh
```

### 1.2 npm ci Error

**오류**:
```
npm ci can only install with existing package-lock.json
```

**해결**:
```bash
cd frontend
npm install
# package-lock.json 생성됨

# Docker 재빌드
docker-compose build frontend
```

### 1.3 Backend Module Error

**오류**:
```
ModuleNotFoundError: No module named 'shared'
```

**해결**:
```bash
# Python path 설정
cd backend
export PYTHONPATH="${PYTHONPATH}:$(pwd)"

# Poetry 재설치
poetry install
```

## 2. Kubernetes 문제

### 2.1 Pod Pending

**오류**:
```
0/3 nodes are available: 3 Insufficient cpu.
```

**해결**:
```bash
# Node 리소스 확인
kubectl describe nodes

# Resource requests 줄이기
helm upgrade kosa-stack ./helm-charts/kosa-stack \
  --set apiGateway.resources.requests.cpu=100m

# AWS로 확장
kubectl --context=aws-cluster scale deployment api-gateway --replicas=10
```

### 2.2 ImagePullBackOff

**오류**:
```
ImagePullBackOff: Failed to pull image "kosa/api-gateway:latest"
```

**해결**:
```bash
# Docker image build & push
docker build -t kosa/api-gateway:latest ./backend
docker push kosa/api-gateway:latest

# 또는 local image 사용
eval $(minikube docker-env)
docker build -t kosa/api-gateway:latest ./backend
```

### 2.3 CrashLoopBackOff

**오류**:
```
CrashLoopBackOff: Error: exit status 1
```

**해결**:
```bash
# Pod logs 확인
kubectl logs deployment/api-gateway -n kosa

# Describe pod
kubectl describe pod api-gateway-xxx -n kosa

# ConfigMap 확인
kubectl get configmap -n kosa
kubectl describe configmap kosa-config -n kosa
```

### 2.4 Service DNS Error

**오류**:
```
nslookup: can't resolve 'mysql-master.kosa.svc.cluster.local'
```

**해결**:
```bash
# Service 확인
kubectl get svc -n kosa

# Endpoints 확인
kubectl get endpoints mysql-master -n kosa

# DNS 확인
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup mysql-master.kosa.svc.cluster.local
```

## 3. Terraform 문제

### 3.1 Proxmox Connection Failed

**오류**:
```
Error: error communicating with Proxmox API: Get "https://...": x509: certificate signed by unknown authority
```

**해결**:
```hcl
provider "proxmox" {
  pm_api_url      = "https://pve1.example.com:8006/api2/json"
  pm_tls_insecure = true  # TLS 검증 비활성화
}
```

### 3.2 AWS Resource Already Exists

**오류**:
```
Error: creating EKS Cluster: ResourceInUseException: cluster already exists
```

**해결**:
```bash
# Import existing resource
terraform import aws_eks_cluster.kosa_eks kosa-eks

# 또는 삭제 후 재생성
aws eks delete-cluster --name kosa-eks
terraform apply
```

### 3.3 S3 Bucket Already Exists

**오류**:
```
Error: creating S3 Bucket: BucketAlreadyExists: The requested bucket name is not available
```

**해결**:
```bash
# Bucket 이름 변경
variable "frontend_bucket_name" {
  default = "kosa-frontend-bucket-unique-123"
}

# 또는 import
terraform import aws_s3_bucket.frontend kosa-frontend-bucket
```

## 4. 클라우드 버스팅 문제

### 4.1 CloudWatch Alarm Not Triggering

**오류**:
```
Alarm not transitioning to ALARM state
```

**해결**:
```bash
# Metric 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=kosa-eks \
  --period 120 \
  --statistics Average

# Alarm 설정 확인
aws cloudwatch describe-alarms --alarm-names kosa-cpu-high
```

### 4.2 Federation Service Not Connected

**오류**:
```
ServiceImport not receiving traffic from remote cluster
```

**해결**:
```bash
# ServiceExport 확인
kubectl get serviceexport -n kosa

# ServiceImport 확인
kubectl get serviceimport -n kosa --context=aws-cluster

# EndpointSlice 확인
kubectl get endpointslice -n kosa
```

## 5. Database 문제

### 5.1 MySQL MHA Master Failed

**오류**:
```
Master MySQL is down, replication stopped
```

**해결**:
```bash
# Slave 상태 확인
kubectl exec -it mysql-slave-0 -n kosa -- \
  mysql -e "SHOW SLAVE STATUS"

# Manual failover
kubectl exec -it mysql-slave-0 -n kosa -- \
  mysql -e "STOP SLAVE; RESET SLAVE ALL;"

# 새 Master로 승격
kubectl exec -it mysql-slave-0 -n kosa -- \
  mysql -e "SET GLOBAL read_only=OFF;"
```

### 5.2 Redis Connection Timeout

**오류**:
```
Redis timeout: connection refused
```

**해결**:
```bash
# Redis pod 확인
kubectl get pods -l app=redis -n kosa

# Redis logs
kubectl logs redis-master-0 -n kosa

# Redis CLI test
kubectl exec -it redis-master-0 -n kosa -- redis-cli ping
```

## 6. 로그 및 디버깅

### 6.1 Pod Logs

```bash
# 실시간 로그
kubectl logs -f deployment/api-gateway -n kosa

# 이전 로그
kubectl logs deployment/api-gateway -n kosa --previous

# Multiple pods
kubectl logs -l app=api-gateway -n kosa
```

### 6.2 Events

```bash
# Namespace events
kubectl get events -n kosa --sort-by='.lastTimestamp'

# Pod events
kubectl describe pod api-gateway-xxx -n kosa
```

### 6.3 Debug Pod

```bash
# Debug container 실행
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Network debug
kubectl run -it --rm netdebug --image=nicolaka/netshoot --restart=Never -- \
  curl http://api-gateway:8000/health
```