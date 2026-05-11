#!/bin/bash

# AWS EKS + RDS + ElastiCache 배포 스크립트

set -e

echo "===== AWS 인프라 배포 시작 ====="

cd infrastructure/aws

# 1. Terraform 초기화
echo "Terraform 초기화 중..."
terraform init

# 2. Terraform plan 실행
echo "Terraform plan 실행 중..."
terraform plan -out=tfplan

# 3. Terraform apply 실행
echo "Terraform apply 실행 중..."
terraform apply tfplan

# 4. EKS 클러스터 정보 출력
echo "EKS 클러스터 정보:"
terraform output eks_cluster_endpoint
terraform output eks_cluster_name

# 5. RDS 정보 출력
echo "RDS 정보:"
terraform output rds_endpoint
terraform output rds_reader_endpoint

# 6. Redis 정보 출력
echo "Redis 정보:"
terraform output redis_endpoint

# 7. CloudFront 정보 출력
echo "CloudFront 정보:"
terraform output cloudfront_domain_name

# 8. kubeconfig 업데이트
echo "kubeconfig 업데이트 중..."
aws eks update-kubeconfig --name kosa-eks --region ap-northeast-2

echo "===== AWS 인프라 배포 완료 ====="

cd ../..

echo ""
echo "다음 명령어로 Helm 차트를 배포하세요:"
echo "  ./deploy-multicluster.sh"