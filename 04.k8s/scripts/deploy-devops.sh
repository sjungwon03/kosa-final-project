#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <ACTION> [COMPONENT]"
  echo "Example:"
  echo "  $0 install                # 모든 DevOps 서비스 설치 (Harbor + Gitea + Percona DB + ArgoCD)"
  echo "  $0 install harbor         # harbor만 설치"
  echo "  $0 uninstall              # 모든 서비스 삭제"
  echo "  $0 uninstall percona-db   # percona-db만 삭제"
  exit 1
fi

ACTION=$1
COMPONENT=${2:-}

if [[ "$ACTION" != "install" && "$ACTION" != "uninstall" ]]; then
  echo "ERROR: ACTION must be 'install' or 'uninstall'"
  exit 1
fi

NAMESPACE="devops"

create_namespace() {
  kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
}

install_helm_chart() {
  local name=$1
  local chart_dir=$2
  local values_file="${chart_dir}/values.yaml"
  
  echo "[$(date '+%F %T')] Installing $name with Helm..."
  
  # Secret 배포 (있는 경우)
  if [ -f "${chart_dir}/00-secret.yaml" ]; then
    kubectl apply -f "${chart_dir}/00-secret.yaml" -n $NAMESPACE
  fi
  
  if [ ! -f "${chart_dir}/Chart.yaml" ]; then
    echo "ERROR: Chart.yaml not found in ${chart_dir}"
    exit 1
  fi
  
  helm dependency update "$chart_dir" || true
  
  if [ -f "$values_file" ]; then
    helm $ACTION $name "$chart_dir" \
      --namespace $NAMESPACE \
      -f "$values_file" \
      --timeout 600s
  else
    helm $ACTION $name "$chart_dir" \
      --namespace $NAMESPACE \
      --timeout 600s
  fi
}

create_namespace

if [ -n "$COMPONENT" ]; then
  case $COMPONENT in
    metallb)
      echo "ERROR: 'metallb' is managed by Ansible (playbooks/k8s.yml). Remove/install from Ansible only."
      exit 1
      ;;
    storage)
      echo "ERROR: 'storage' (Ceph CSI/StorageClass) is managed by Ansible (playbooks/k8s.yml). Remove/install from Ansible only."
      exit 1
      ;;
    harbor)
      install_helm_chart harbor "${MANIFESTS_DIR}/harbor"
      ;;
    percona-db)
      install_helm_chart percona-db "${MANIFESTS_DIR}/percona-db"
      ;;
    gitea)
      install_helm_chart gitea "${MANIFESTS_DIR}/gitea"
      ;;
    argocd)
      install_helm_chart argocd "${MANIFESTS_DIR}/argocd"
      ;;
    *)
      echo "ERROR: Unknown component: $COMPONENT"
      exit 1
      ;;
  esac
else
  install_helm_chart harbor "${MANIFESTS_DIR}/harbor"
  install_helm_chart gitea "${MANIFESTS_DIR}/gitea"
  install_helm_chart percona-db "${MANIFESTS_DIR}/percona-db"
  install_helm_chart argocd "${MANIFESTS_DIR}/argocd"
fi

echo "[$(date '+%F %T')] done"
