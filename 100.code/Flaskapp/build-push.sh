#!/bin/bash
set -euo pipefail

# ── 경로 설정 ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── AWS 자격증명 사전 확인 ─────────────────────────────
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "  AWS 자격증명이 설정되지 않았습니다."
  echo "   export AWS_ACCESS_KEY_ID=..."
  echo "   export AWS_SECRET_ACCESS_KEY=..."
  exit 1
fi

# ── 설정 ──────────────────────────────────────────────
AWS_REGION="ap-northeast-2"
ECR_URL="080252689380.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_NAME="flaskapp"

# 이미지 태그: git commit SHA (앞 7자리)
GIT_SHA=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)
IMAGE_TAG="${GIT_SHA}"
FULL_IMAGE="${ECR_URL}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "[INFO]빌드 시작"
echo "  이미지: ${FULL_IMAGE}"
echo ""

# ── ECR 로그인 ─────────────────────────────────────────
echo "[INFO]ECR 로그인"
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_URL"

# ── Docker 빌드 (linux/amd64 고정: K8s 노드가 x86_64) ─
echo "[INFO]Docker 빌드"
docker build --platform linux/amd64 -t "${IMAGE_NAME}:${IMAGE_TAG}" "$SCRIPT_DIR"

# ── ECR 태깅 + Push ────────────────────────────────────
echo "[INFO]ECR Push"
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$FULL_IMAGE"
docker push "$FULL_IMAGE"

# latest 태그도 함께 push
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${ECR_URL}/${IMAGE_NAME}:latest"
docker push "${ECR_URL}/${IMAGE_NAME}:latest"

echo ""
echo "[DONE] ${FULL_IMAGE}"
echo ""
echo "다음 단계: infra 레포에서 아래 값으로 image.tag를 업데이트하세요"
echo "  파일: helm/flaskapp/values.yaml"
echo "  tag: \"${IMAGE_TAG}\""
