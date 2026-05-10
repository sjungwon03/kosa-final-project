#!/bin/bash

# S3 배포 스크립트

set -e

# 환경 변수
BUCKET_NAME="kosa-frontend-bucket"
REGION="ap-northeast-2"
DISTRIBUTION_ID=""

echo "프론트엔드 빌드 시작..."
cd frontend
npm run build

echo "S3에 배포 시작..."
aws s3 sync out/ s3://${BUCKET_NAME} --delete --region ${REGION}

echo "CloudFront 캐시 무효화..."
if [ -n "$DISTRIBUTION_ID" ]; then
    aws cloudfront create-invalidation --distribution-id ${DISTRIBUTION_ID} --paths "/*"
fi

echo "배포 완료!"