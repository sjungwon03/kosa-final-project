#!/bin/bash

# K8s 배포 스크립트

set -e

NAMESPACE="kosa"

echo "K8s 배포 시작..."

# 네임스페이스 생성
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# MySQL 배포
echo "MySQL 배포 중..."
kubectl apply -f kubernetes/mysql/mysql.yaml

# Redis 배포
echo "Redis 배포 중..."
kubectl apply -f kubernetes/backend/redis.yaml

# 백엔드 서비스 배포
echo "백엔드 서비스 배포 중..."
kubectl apply -f kubernetes/backend/employee-service.yaml
kubectl apply -f kubernetes/backend/welfare-service.yaml
kubectl apply -f kubernetes/backend/api-gateway.yaml

# Ingress 생성
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kosa-ingress
  namespace: ${NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: api.kosa.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 8000
EOF

echo "K8s 배포 완료!"
echo "서비스 확인: kubectl get pods -n ${NAMESPACE}"
echo "서비스 접속: http://api.kosa.local (로컬 /etc/hosts 설정 필요)"