# Helm Chart Guide

## 1. 개요

Helm Chart를 사용하여 Kubernetes 애플리케이션을 패키징하고 배포합니다.

## 2. Chart 구조

```
helm-charts/kosa-stack/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── values-onprem.yaml      # On-premise values
├── values-aws.yaml         # AWS values
└── templates/
    ├── api-gateway-deployment.yaml
    ├── api-gateway-service.yaml
    ├── api-gateway-hpa.yaml
    ├── employee-service-deployment.yaml
    ├── employee-service-service.yaml
    ├── employee-service-hpa.yaml
    ├── welfare-service-deployment.yaml
    ├── welfare-service-service.yaml
    ├── welfare-service-hpa.yaml
    ├── namespace-config.yaml
    ├── service-export.yaml
    ├── service-import.yaml
    └── ingress.yaml
```

## 3. Chart.yaml

```yaml
apiVersion: v2
name: kosa-stack
description: KOSA Employee Management System
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled

  - name: mysql
    version: "9.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: mysql.enabled
```

## 4. Values 구성

### 4.1 기본 Values (values.yaml)

```yaml
global:
  env: production
  namespace: kosa
  
  cloudbursting:
    enabled: true
    primaryCluster: onprem
    secondaryCluster: aws
    scalingThreshold: 70

apiGateway:
  replicaCount: 2
  autoscaling:
    minReplicas: 2
    maxReplicas: 20
```

### 4.2 온프레미스 Values (values-onprem.yaml)

```yaml
apiGateway:
  replicaCount: 2
  autoscaling:
    maxReplicas: 20  # 온프레미스 리소스 제한

mysql:
  enabled: true      # 온프레미스 MySQL 사용
  primary:
    persistence:
      size: 50Gi

redis:
  enabled: true      # 온프레미스 Redis 사용
```

### 4.3 AWS Values (values-aws.yaml)

```yaml
apiGateway:
  replicaCount: 0    # 기본 0, 부하 시 확장
  autoscaling:
    maxReplicas: 100

mysql:
  enabled: false     # RDS 사용

redis:
  enabled: false     # ElastiCache 사용

externalServices:
  mysql:
    enabled: true
    host: kosa-rds.xxx.rds.amazonaws.com
  redis:
    enabled: true
    host: kosa-redis.xxx.cache.amazonaws.com
```

## 5. Templates

### 5.1 Deployment Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .Values.apiGateway.replicaCount }}
  template:
    spec:
      containers:
      - name: api-gateway
        image: "{{ .Values.apiGateway.image.repository }}:{{ .Values.apiGateway.image.tag }}"
        env:
        - name: ENV
          value: {{ .Values.global.env }}
        resources:
          {{- toYaml .Values.apiGateway.resources | nindent 10 }}
```

### 5.2 HPA Template

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: {{ .Values.apiGateway.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.apiGateway.autoscaling.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.apiGateway.autoscaling.targetCPUUtilizationPercentage }}
```

### 5.3 Service Template

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: {{ .Values.global.namespace }}
spec:
  type: {{ .Values.apiGateway.service.type }}
  ports:
  - port: {{ .Values.apiGateway.service.port }}
    targetPort: 8000
  selector:
    app: api-gateway
```

## 6. Helm Commands

### 6.1 설치

```bash
# 기본 values 사용
helm install kosa-stack ./helm-charts/kosa-stack --namespace kosa

# 온프레미스 values 사용
helm install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --values ./helm-charts/kosa-stack/values-onprem.yaml

# AWS values 사용
helm install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --values ./helm-charts/kosa-stack/values-aws.yaml
```

### 6.2 업그레이드

```bash
helm upgrade kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --values ./helm-charts/kosa-stack/values-onprem.yaml
```

### 6.3 삭제

```bash
helm uninstall kosa-stack --namespace kosa
```

### 6.4 상태 확인

```bash
# Chart 목록
helm list -n kosa

# Chart 상태
helm status kosa-stack -n kosa

# Values 확인
helm get values kosa-stack -n kosa

# Manifest 확인
helm get manifest kosa-stack -n kosa
```

## 7. Template Testing

```bash
# Dry-run
helm install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --dry-run \
  --debug

# Template 렌더링
helm template kosa-stack ./helm-charts/kosa-stack \
  --values ./helm-charts/kosa-stack/values-onprem.yaml
```

## 8. Custom Values

### 8.1 Runtime Override

```bash
helm upgrade --install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --set apiGateway.replicaCount=5 \
  --set apiGateway.autoscaling.maxReplicas=30
```

### 8.2 Secret Injection

```bash
helm upgrade --install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --set mysql.auth.rootPassword=secret-password \
  --set jwt.secretKey=jwt-secret
```

## 9. 롤백

```bash
# History 확인
helm history kosa-stack -n kosa

# 롤백
helm rollback kosa-stack 1 -n kosa
```