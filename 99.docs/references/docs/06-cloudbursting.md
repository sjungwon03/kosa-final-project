# 클라우드 버스팅 (CloudBursting)

## 1. 개요

클라우드 버스팅은 온프레미스 리소스가 부족할 때 AWS 클라우드 리소스를 자동으로 확장하여 트래픽을 처리하는 기술입니다.

## 2. 동작 방식

### 2.1 트리거 조건
- 온프레미스 CPU 사용률 70% 초과
- Memory 사용률 80% 초과
- Pod Pending 상태 지속

### 2.2 확장 프로세스

```
1. CloudWatch Alarm 트리거
   ↓
2. AWS EKS Node Group 활성화
   ↓  
3. replicas: 0 → 10 (API Gateway)
   replicas: 0 → 5 (Employee/Welfare Service)
   ↓
4. Kubernetes Federation으로 서비스 연동
   ↓
5. ServiceImport로 트래픽 분산
   ↓
6. 온프레미스 → AWS 트래픽 라우팅
```

### 2.3 복구 프로세스

```
1. 온프레미스 CPU 사용률 30% 이하
   ↓
2. AWS replicas 감소
   ↓
3. Node Group replicas: 10 → 0
   ↓
4. 트래픽 온프레미스로 복원
```

## 3. Kubernetes Federation v2

### 3.1 구성 요소

#### ServiceExport
다른 클러스터에서 사용할 서비스를 등록합니다.

```yaml
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  name: api-gateway
  namespace: kosa
```

#### ServiceImport
다른 클러스터의 서비스를 가져옵니다.

```yaml
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceImport
metadata:
  name: api-gateway
  namespace: kosa
spec:
  type: ClusterSetIP
  ports:
  - port: 8000
```

### 3.2 EndpointSlice
멀티클러스터 엔드포인트를 관리합니다.

## 4. 트래픽 라우팅

### 4.1 Load Balancer
- 온프레미스: MetalLB (Public VLAN 100)
- AWS: NLB (Network Load Balancer)

### 4.2 트래픽 분산
- 온프레미스: 70-80%
- AWS: 20-30% (부하 시)

## 5. CloudWatch 설정

### 5.1 Alarms

#### CPU High Alarm
```hcl
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "kosa-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
}
```

#### CPU Low Alarm
```hcl
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  threshold = "30"
}
```

### 5.2 Auto Scaling Policy
- Scale Up: replicas +2
- Scale Down: replicas -1

## 6. 클라우드 버스팅 트리거 Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: cloudburst-trigger
spec:
  template:
    spec:
      containers:
      - name: trigger
        image: bitnami/kubectl:latest
        command:
        - /bin/sh
        - -c
        - |
          CPU_USAGE=$(kubectl top pods | grep api-gateway | awk '{print $2}')
          if [ "${CPU_USAGE}" -gt 70 ]; then
            kubectl --context=aws-cluster scale deployment api-gateway --replicas=10
          fi
```

## 7. 모니터링

### 7.1 CloudWatch Dashboard
- EKS CPU/Memory
- Pod Count
- Network Traffic

### 7.2 Metrics
- `kosa_cpu_usage_percentage`
- `kosa_pod_count`
- `kosa_traffic_distribution`

## 8. 비용 관리

### 8.1 AWS 리소스
- EKS Node Group: m5.large, m5.xlarge
- Fargate Profile: On-demand

### 8.2 비용 최적화
- Replicas 0으로 시작 (부하 시만 활성화)
- Spot Instances 사용 (개발용)
- Auto-scaling cooldown 설정

## 9. 테스트

```bash
# 부하 생성
kubectl run load-generator --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://api-gateway:8000; done"

# AWS replicas 확인
kubectl get deployment -n kosa --context=aws-cluster

# CloudWatch Alarm 확인
aws cloudwatch describe-alarms --alarm-names kosa-cpu-high
```