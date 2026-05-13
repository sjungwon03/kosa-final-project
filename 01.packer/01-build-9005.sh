#!/bin/bash

# K8s 노드 템플릿(9005) Packer 빌드 자동화 스크립트
# 실행: 로컬(또는 빌드 서버)
#
# [2026-05-13] 최초 작성

set -e

# TODO: 컨트롤 노드 공용 계정 사용 시 개인 식별 방법 필요 (개인 계정 분리 또는 환경변수 규칙 수립)
BUILT_BY=$(git config user.name 2>/dev/null || whoami)
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# TODO: 9003 존재 여부 자동 검증
# ssh root@<proxmox_host> "qm list | grep -q ' 9003 '" || { echo "ERROR: 9003 템플릿 없음. 01-build-9003.sh 먼저 실행"; exit 1; }

packer init ubuntu-2404-k8s/
packer build \
  -var="built_by=$BUILT_BY" \
  -var="git_commit=$GIT_COMMIT" \
  -var="git_branch=$GIT_BRANCH" \
  -var-file="credentials.pkr.hcl" \
  -var-file="ubuntu-2404-k8s/ssh-credentials.pkrvars.hcl" \
  ubuntu-2404-k8s/
