# 운영 가이드

## 1. 일상 운영 작업

### 1.1 로그 확인

```bash
kubectl logs -f deployment/employee-service -n employee-management
kubectl logs -f deployment/product-service -n welfare-mall
```

### 1.2 상태 모니터링

```bash
kubectl get pods -n employee-management
kubectl get pods -n welfare-mall
kubectl top pods -n employee-management
kubectl top nodes
```

### 1.3 리소스 사용량

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl top pod <pod-name> -n <namespace>
```

## 2. 성능 최적화

### 2.1 Pod 리소스 조정

```bash
kubectl set resources deployment/employee-service \
  --requests=cpu=500m,memory=512Mi \
  --limits=cpu=1000m,memory=1Gi \
  -n employee-management
```

### 2.2 HPA 설정

```bash
kubectl patch horizontalpodautoscaler employee-service-hpa \
  -p '{"spec":{"minReplicas":3,"maxReplicas":15}}' \
  -n employee-management
```

### 2.3 Node 스케일링

```bash
eksctl scale nodegroup \
  --cluster welfare-mall-cluster \
  --name general \
  --nodes 5
```

## 3. 보안 운영

### 3.1 Secret 업데이트

```bash
kubectl create secret generic employee-service-secret \
  --from-literal=DB_PASSWORD=NewSecurePassword \
  --namespace=employee-management \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/employee-service \
  -n employee-management
```

### 3.2 TLS 인증서 재발급

```bash
kubectl delete secret welfare-mall-tls -n welfare-mall

kubectl get certificaterequest -n welfare-mall
```

### 3.3 접근 제어

```bash
kubectl auth can-i get pods --as=user@example.com -n employee-management
kubectl auth can-i list secrets --as=admin -n welfare-mall
```

## 4. 데이터베이스 운영

### 4.1 MySQL MHA 상태 확인

```bash
masterha_check_status --conf=/etc/mha/app1.cnf
masterha_check_repl --conf=/etc/mha/app1.cnf
```

### 4.2 RDS 성능 확인

```bash
aws rds describe-db-instances \
  --db-instance-identifier production-welfare-db

aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=production-welfare-db \
  --statistics Average \
  --period 3600 \
  --start-time $(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### 4.3 데이터베이스 백업

```bash
mysqldump -h master.db.local -u root -p employee_db \
  --single-transaction \
  --routines \
  --triggers \
  > /backup/employee_db_$(date +%Y%m%d).sql

aws rds create-db-snapshot \
  --db-instance-identifier production-welfare-db \
  --db-snapshot-identifier welfare-db-backup-$(date +%Y%m%d)
```

## 5. 로깅 운영

### 5.1 로그 조회

```bash
aws s3 ls s3://hybrid-cloud-logs/

aws s3 cp s3://hybrid-cloud-logs/welfare-mall/2024-01-01/ ./logs/
```

### 5.2 로그 검색

```bash
grep "ERROR" logs/*.json | jq .
grep "Employee created" logs/*.json | jq .
```

### 5.3 로그 보관 설정

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket hybrid-cloud-logs \
  --lifecycle-configuration file://lifecycle-policy.json
```

## 6. 장애 대응

### 6.1 Pod 장애

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
kubectl delete pod <pod-name> -n <namespace>
```

### 6.2 Node 장애

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

### 6.3 PVC 장애

```bash
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>
```

### 6.4 서비스 장애

```bash
kubectl get svc -n <namespace>
kubectl describe svc <svc-name> -n <namespace>
kubectl get endpoints <svc-name> -n <namespace>
```

## 7. 페일오버 운영

### 7.1 MySQL MHA 페일오버

```bash
masterha_manager --conf=/etc/mha/app1.cnf

masterha_master_switch --conf=/etc/mha/app1.cnf \
  --master_state=alive \
  --new_master_host=slave1.db.local
```

### 7.2 RDS 페일오버

```bash
aws rds reboot-db-instance \
  --db-instance-identifier production-welfare-db \
  --force-failover
```

### 7.3 EKS Node 페일오버

```bash
eksctl drain nodegroup \
  --cluster welfare-mall-cluster \
  --name general \
  --node <node-name>

eksctl delete nodegroup \
  --cluster welfare-mall-cluster \
  --name general
```

## 8. 업그레이드 운영

### 8.1 애플리케이션 업그레이드

```bash
kubectl set image deployment/employee-service \
  employee-service=harbor.local/employee-management/employee-service:v2.0.0 \
  -n employee-management

kubectl rollout status deployment/employee-service \
  -n employee-management
```

### 8.2 Kubernetes 업그레이드

```bash
eksctl upgrade cluster \
  --name welfare-mall-cluster \
  --version 1.29 \
  --approve
```

### 8.3 Terraform 업그레이드

```bash
terraform init -upgrade
terraform plan
terraform apply
```

## 9. 모니터링 설정

### 9.1 Grafana 대시보드

1. Grafana 접속: `https://grafana.example.com`
2. 로그인: admin / admin123
3. Data Source 추가: Prometheus
4. 대시보드 import:
   - Node Exporter: ID 1860
   - Kubernetes Pods: ID 6417
   - NGINX Ingress: ID 9614

### 9.2 알림 설정

```yaml
groups:
- name: employee-service
  rules:
  - alert: HighCPUUsage
    expr: rate(container_cpu_usage_seconds_total{namespace="employee-management"}[5m]) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage detected"

  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total{namespace="employee-management"}[15m]) > 0
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "Pod is crash looping"
```

### 9.3 Slack 알림

```yaml
receivers:
- name: 'slack-notifications'
  slack_configs:
  - send_resolved: true
    channel: '#alerts'
    api_url: 'https://hooks.slack.com/services/XXXX'
```

## 10. 성능 테스트

### 10.1 부하 테스트

```bash
kubectl run load-generator \
  --image=busybox \
  --restart=Never \
  --namespace=employee-management \
  -- sh -c "while true; do wget -q -O- http://employee-service:3001/api/employees; done"
```

### 10.2 API 벤치마크

```bash
wrk -t4 -c100 -d30s http://employee.example.com/api/employees
```

### 10.3 데이터베이스 성능

```bash
mysqlslap -h master.db.local -u root -p \
  --concurrency=50 \
  --iterations=10 \
  --number-int-cols=5 \
  --number-char-cols=20 \
  --auto-generate-sql \
  --auto-generate-sql-add-auto \
  --engine=innodb
```

## 11. 용량 계획

### 11.1 리소스 사용량 추적

```bash
kubectl top pods --sum=true -n employee-management
kubectl top nodes --sum=true
```

### 11.2 스토리지 사용량

```bash
kubectl get pv
kubectl describe pv <pv-name>
```

### 11.3 네트워크 사용량

```bash
kubectl exec -it <pod-name> -n <namespace> -- \
  apt-get update && apt-get install -y iftop
iftop -i eth0
```

## 12. 정기 점검

### 12.1 일일 점검

- Pod 상태 확인
- Node 상태 확인
- 리소스 사용량 확인
- 에러 로그 확인
- 백업 상태 확인

### 12.2 주간 점검

- 성능 메트릭 분석
- 보안 업데이트 확인
- 용량 계획 검토
- VPN 연결 상태 확인

### 12.3 월간 점검

- Kubernetes 버전 확인
- 데이터베이스 성능 검토
- 비용 분석
- 보안 정책 검토

## 13. 문서화

### 13.1 운영 로그

```bash
echo "$(date): Upgraded employee-service to v2.0.0" >> /var/log/ops.log
echo "$(date: DB backup completed successfully" >> /var/log/ops.log
```

### 13.2 변경 이력

Git commit message에 운영 변경 내역 기록

### 13.3 문제 해결 기록

장애 발생 시:
1. 문제 현상 기록
2. 원인 분석
3. 해결 방법
4. 예방 조치

## 14. 비용 관리

### 14.1 AWS 비용 확인

```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

### 14.2 리소스 정리

```bash
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId'
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
```

## 15. 연락처 및 지원

### 15.1 장애 대응 연락망

- 인프라: ops-infra@example.com
- 애플리케이션: ops-app@example.com
- 데이터베이스: ops-db@example.com

### 15.2 AWS 지원

AWS Support Center: https://console.aws.amazon.com/support

### 15.3 커뮤니티 지원

- Kubernetes Slack: kubernetes.slack.com
- NestJS Discord: discord.gg/nestjs
- Stack Overflow