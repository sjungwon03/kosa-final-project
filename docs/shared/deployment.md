# 배포 가이드

## 1. 사전 요구사항

### 클라우드 환경 (AWS)
- AWS 계정 및 IAM 권한
- Terraform 1.5+ 설치
- AWS CLI v2 설치 및 구성
- kubectl 설치

### 온프레미스 환경
- Kubernetes 클러스터 구성
- Harbor 컨테이너 레지스트리
- GitLab 서버
- MySQL MHA 구성

### 개발 환경
- Node.js 18+ 설치
- Docker 및 Docker Compose 설치
- Helm 3 설치

## 2. 인프라 프로비저닝

### 2.1 Terraform 초기화

```bash
cd infrastructure/terraform/aws

terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=hybrid-cloud/terraform.tfstate" \
  -backend-config="region=ap-northeast-2"
```

### 2.2 Terraform 계획 확인

```bash
terraform plan \
  -var="aws_region=ap-northeast-2" \
  -var="environment=production" \
  -var="db_password=YourSecurePassword" \
  -var="onprem_vpn_ip=203.0.113.1" \
  -out=tfplan
```

### 2.3 Terraform 실행

```bash
terraform apply tfplan
```

### 2.4 출력 확인

```bash
terraform output
```

주요 출력:
- `eks_cluster_endpoint`: EKS 클러스터 엔드포인트
- `rds_endpoint`: RDS 엔드포인트
- `s3_bucket_name`: S3 버킷 이름
- `vpn_connection_id`: VPN 연결 ID

## 3. Kubernetes 클러스터 구성

### 3.1 EKS 클러스터 연결

```bash
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name welfare-mall-cluster
```

### 3.2 온프레미스 클러스터 연결

```bash
kubectl config use-context onprem-cluster
```

### 3.3 Namespace 생성

```bash
kubectl apply -f infrastructure/kubernetes/onprem/namespace/
kubectl apply -f infrastructure/kubernetes/cloud/namespace/
```

## 4. Harbor 레지스트리 설정

### 4.1 Harbor 설치 (온프레미스)

```bash
cd services/harbor

docker-compose up -d
```

### 4.2 Harbor 구성

```bash
docker exec harbor-core ./prepare
docker-compose up -d
```

### 4.3 프로젝트 생성

```bash
curl -X POST "https://harbor.local/api/v2.0/projects" \
  -u "admin:HarborAdmin123" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "employee-management",
    "public": false
  }'

curl -X POST "https://harbor.local/api/v2.0/projects" \
  -u "admin:HarborAdmin123" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "welfare-mall",
    "public": false
  }'
```

## 5. GitLab CI/CD 설정

### 5.1 GitLab Runner 설치

```bash
docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest

docker exec -it gitlab-runner gitlab-runner register
```

### 5.2 GitLab Variables 설정

GitLab UI에서 설정:

**Variables:**
- `HARBOR_PASSWORD`: Harbor 관리자 비밀번호
- `SLACK_WEBHOOK_URL`: Slack 웹훅 URL
- `AWS_ACCESS_KEY_ID`: AWS 액세스 키
- `AWS_SECRET_ACCESS_KEY`: AWS 시크릿 키

**Kubernetes Contexts:**
- `onprem-cluster`: 온프레미스 K8s 클러스터
- `eks-cluster`: EKS 클러스터

## 6. 애플리케이션 배포

### 6.1 온프레미스 배포 (사원관리)

```bash
kubectl config use-context onprem-cluster

kubectl apply -f infrastructure/kubernetes/onprem/config/

kubectl apply -f infrastructure/kubernetes/onprem/employee-service/
kubectl apply -f infrastructure/kubernetes/onprem/auth-service/
```

### 6.2 클라우드 배포 (복지포인트몰)

```bash
kubectl config use-context eks-cluster

kubectl apply -f infrastructure/kubernetes/cloud/config/

kubectl apply -f infrastructure/kubernetes/cloud/product-service/
kubectl apply -f infrastructure/kubernetes/cloud/order-service/
kubectl apply -f infrastructure/kubernetes/cloud/point-service/
kubectl apply -f infrastructure/kubernetes/cloud/api-gateway/
```

### 6.3 배포 확인

```bash
kubectl get pods -n employee-management
kubectl get pods -n welfare-mall

kubectl get services -n employee-management
kubectl get services -n welfare-mall
```

## 7. VPN 연결 구성

### 7.1 온프레미스 VPN 장치 구성

AWS VPN 연결 정보를 Terraform 출력에서 확인:

```bash
terraform output tunnel1_address
terraform output tunnel2_address
terraform output tunnel1_cgw_inside_address
terraform output tunnel2_cgw_inside_address
```

### 7.2 온프레미스 라우터 설정 (Cisco 예시)

```
crypto isakmp policy 10
 encr aes
 hash sha
 authentication pre-share
 group 2

crypto ipsec transform-set AWS-TRANSFORM esp-aes esp-sha-hmac

crypto map AWS-MAP 10 ipsec-isakmp
 set peer <AWS_TUNNEL1_ADDRESS>
 set peer <AWS_TUNNEL2_ADDRESS>
 set transform-set AWS-TRANSFORM
 match address AWS-ACL

access-list AWS-ACL permit ip 192.168.1.0 0.0.0.255 10.0.0.0 0.255.255.255

interface Tunnel1
 ip address <TUNNEL1_CGW_INSIDE_ADDRESS> 255.255.255.252
 tunnel destination <AWS_TUNNEL1_ADDRESS>
 tunnel source <YOUR_PUBLIC_IP>
 crypto map AWS-MAP
```

## 8. 모니터링 구성

### 8.1 Prometheus & Grafana 설치

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace

helm install grafana prometheus-community/grafana \
  --namespace monitoring \
  --set adminPassword=admin123
```

### 8.2 Loki 로깅 설치

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true
```

## 9. 보안 구성

### 9.1 TLS 인증서 구성

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### 9.2 Network Policies 적용

```bash
kubectl apply -f infrastructure/kubernetes/network-policies/
```

## 10. 데이터베이스 설정

### 10.1 MySQL MHA 구성 (온프레미스)

```bash
sudo yum install -y mysql-mha

cd /etc/mha
vim app1.cnf

[server default]
manager_workdir=/var/log/mha/app1
manager_log=/var/log/mha/app1/manager.log
user=mha
password=mha_password
repl_user=repl
repl_password=repl_password
ssh_user=root

[server1]
hostname=master.db.local
candidate_master=1

[server2]
hostname=slave1.db.local
candidate_master=1

[server3]
hostname=slave2.db.local
no_master=1

masterha_manager --conf=/etc/mha/app1.cnf
```

### 10.2 RDS 연결 (클라우드)

```bash
mysql -h production-welfare-db.xxxxx.rds.amazonaws.com \
  -u admin \
  -p \
  -e "CREATE DATABASE welfare_db;"
```

## 11. 로깅 백업 설정

### 11.1 S3 로그 백업 CronJob 배포

```bash
kubectl apply -f services/logging/log-backup-cronjob.yaml
```

### 11.2 IAM Role 생성 (EKS)

```bash
eksctl create iamserviceaccount \
  --cluster welfare-mall-cluster \
  --namespace welfare-mall \
  --name log-backup-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
  --approve \
  --override-existing-serviceaccounts
```

## 12. 배포 완료 확인

### 12.1 서비스 상태 확인

```bash
kubectl get all -n employee-management
kubectl get all -n welfare-mall
```

### 12.2 엔드포인트 테스트

```bash
curl -k https://employee.example.com/api/employees
curl -k https://welfare.example.com/api/products
```

### 12.3 VPN 연결 테스트

```bash
ping 10.0.1.1  # AWS VPC IP
ping 192.168.1.1  # 온프레미스 IP
```

## 13. 롤링 업데이트

### 13.1 이미지 업데이트

```bash
kubectl set image deployment/employee-service \
  employee-service=harbor.local/employee-management/employee-service:v1.1.0 \
  -n employee-management

kubectl rollout status deployment/employee-service \
  -n employee-management
```

### 13.2 롤백

```bash
kubectl rollout undo deployment/employee-service \
  -n employee-management
```

## 14. 문제 해결

### 14.1 Pod 로그 확인

```bash
kubectl logs -f deployment/employee-service -n employee-management
```

### 14.2 Pod 상태 확인

```bash
kubectl describe pod <pod-name> -n employee-management
```

### 14.3 이벤트 확인

```bash
kubectl get events -n employee-management --sort-by='.lastTimestamp'
```

## 15. 백업 및 복구

### 15.1 데이터베이스 백업

```bash
mysqldump -h master.db.local -u root -p employee_db > employee_db_backup.sql

aws rds create-db-snapshot \
  --db-instance-identifier production-welfare-db \
  --db-snapshot-identifier welfare-db-backup-$(date +%Y%m%d)
```

### 15.2 데이터베이스 복구

```bash
mysql -h master.db.local -u root -p employee_db < employee_db_backup.sql

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier welfare-db-restored \
  --db-snapshot-identifier welfare-db-backup-20240101
```

## 16. 확장

### 16.1 Node Group 추가

```bash
eksctl create nodegroup \
  --cluster welfare-mall-cluster \
  --name additional-workers \
  --node-type m5.large \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5
```

### 16.2 HPA 설정

```bash
kubectl autoscale deployment employee-service \
  --min=3 --max=10 --cpu-percent=70 \
  -n employee-management
```