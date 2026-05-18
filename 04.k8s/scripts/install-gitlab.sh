#!/bin/bash
# GitLab Operator 설치/제거 스크립트
# 선행 조건: cert-manager 설치 완료 및 webhook 준비 상태
# 참고: 04.k8s/manifests/gitlab-operator/README.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GL_DIR="${SCRIPT_DIR}/../manifests/gitlab-operator"
GL_VERSION="${GL_OPERATOR_VERSION:-2.9.0}"
GL_MANIFEST_URL="https://gitlab.com/api/v4/projects/18899486/packages/generic/gitlab-operator/${GL_VERSION}/gitlab-operator-kubernetes-${GL_VERSION}.yaml"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <install|uninstall>"
  exit 1
fi

ACTION=$1

if [[ "$ACTION" != "install" && "$ACTION" != "uninstall" ]]; then
  echo "ERROR: ACTION must be 'install' or 'uninstall'"
  exit 1
fi

log() {
  echo "[$(date '+%F %T')] $*"
}

wait_cert_manager_webhook() {
  log "Checking cert-manager webhook readiness..."
  if ! kubectl get deployment cert-manager-webhook -n cert-manager &>/dev/null; then
    echo "ERROR: cert-manager webhook not found. Install cert-manager first."
    echo "  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml"
    exit 1
  fi
  log "Waiting for cert-manager webhook to be ready (max 120s)..."
  kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s
  # webhook TLS 초기화 대기 (x509 오류 방지)
  sleep 15
  log "cert-manager webhook ready"
}

install_gitlab() {
  wait_cert_manager_webhook

  log "Installing GitLab Operator ${GL_VERSION}..."
  kubectl create namespace gitlab-system --dry-run=client -o yaml | kubectl apply -f -

  kubectl apply -f "${GL_MANIFEST_URL}"

  log "Waiting for GitLab Operator to be ready..."
  kubectl rollout status deployment/gitlab-controller-manager -n gitlab-system --timeout=300s

  log "Applying GitLab CR..."
  kubectl apply -f "${GL_DIR}/gitlab-cr.yaml"

  log "GitLab CR applied. Initialization takes 15-30 min."
  log "Monitor: kubectl get pods -n gitlab-system -w"
}

uninstall_gitlab() {
  log "Deleting GitLab CR..."
  kubectl delete -f "${GL_DIR}/gitlab-cr.yaml" --ignore-not-found || true

  log "Waiting for GitLab resources to be removed..."
  kubectl wait --for=delete gitlab/gitlab -n gitlab-system --timeout=300s 2>/dev/null || true

  log "Deleting GitLab Operator ${GL_VERSION}..."
  kubectl delete -f "${GL_MANIFEST_URL}" --ignore-not-found || true

  log "Uninstall complete"
}

case "$ACTION" in
  install)   install_gitlab ;;
  uninstall) uninstall_gitlab ;;
esac
