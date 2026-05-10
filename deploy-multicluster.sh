#!/bin/bash

# 온프레미스 + AWS 클라우드 버스팅 배포 스크립트

set -e

NAMESPACE="kosa"
ONPREM_CONTEXT="onprem-cluster"
AWS_CONTEXT="aws-cluster"

echo "===== 멀티클러스터 배포 시작 ====="

# 1. 온프레미스 클러스터에 Helm 배포
echo "온프레미스 클러스터에 배포 중..."
kubectl config use-context ${ONPREM_CONTEXT}

helm upgrade --install kosa-stack ./helm-charts/kosa-stack \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --values ./helm-charts/kosa-stack/values-onprem.yaml \
  --wait

echo "온프레미스 배포 완료!"

# 2. AWS EKS 클러스터에 Helm 배포
echo "AWS EKS 클러스터에 배포 중..."
kubectl config use-context ${AWS_CONTEXT}

helm upgrade --install kosa-stack ./helm-charts/kosa-stack \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --values ./helm-charts/kosa-stack/values-aws.yaml \
  --wait

echo "AWS 배포 완료!"

# 3. Kubernetes Federation 설정
echo "Kubernetes Federation 설정 중..."
kubectl config use-context ${ONPREM_CONTEXT}

kubectl apply -f ./kubernetes-multicluster/federation.yaml

echo "Federation 설정 완료!"

# 4. Istio 멀티클러스터 설정
echo "Istio 멀티클러스터 설정 중..."

kubectl apply -f ./kubernetes-multicluster/istio-gateway.yaml --context=${ONPREM_CONTEXT}
kubectl apply -f ./kubernetes-multicluster/istio-gateway.yaml --context=${AWS_CONTEXT}

echo "Istio 설정 완료!"

# 5. 클라우드 버스팅 트리거 설정
echo "클라우드 버스팅 트리거 설정 중..."
kubectl apply -f ./kubernetes-multicluster/cloudburst-trigger.yaml --context=${ONPREM_CONTEXT}

echo "===== 배포 완료 ====="

echo ""
echo "배포 정보:"
echo "  온프레미스: ${ONPREM_CONTEXT}"
echo "  AWS: ${AWS_CONTEXT}"
echo ""
echo "서비스 확인:"
echo "  온프레미스 pods: kubectl get pods -n ${NAMESPACE} --context=${ONPREM_CONTEXT}"
echo "  AWS pods: kubectl get pods -n ${NAMESPACE} --context=${AWS_CONTEXT}"
echo ""
echo "클라우드 버스팅 상태:"
echo "  kubectl logs job/cloudburst-trigger -n ${NAMESPACE} --context=${ONPREM_CONTEXT}"