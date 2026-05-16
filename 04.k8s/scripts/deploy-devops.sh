#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <ACTION> [COMPONENT]"
  echo "Example:"
  echo "  $0 install                # 모든 서비스 설치 (MetalLB + Harbor + GitLab + ArgoCD)"
  echo "  $0 install harbor         # harbor만 설치"
  echo "  $0 uninstall              # 모든 서비스 삭제"
  echo "  $0 uninstall gitlab       # gitlab만 삭제"
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

install_metallb() {
  echo "[$(date '+%F %T')] Installing MetalLB..."
  kubectl apply -f "${MANIFESTS_DIR}/metallb/"
}

install_helm_chart() {
  local name=$1
  local chart_dir=$2
  local values_file="${chart_dir}/values.yaml"
  
  echo "[$(date '+%F %T')] Installing $name with Helm..."
  
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
      if [[ "$ACTION" == "install" ]]; then
        install_metallb
      else
        kubectl delete -f "${MANIFESTS_DIR}/metallb/" --ignore-not-found=true
      fi
      ;;
    harbor)
      install_helm_chart harbor "${MANIFESTS_DIR}/harbor"
      ;;
    gitlab)
      install_helm_chart gitlab "${MANIFESTS_DIR}/gitlab"
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
  install_metallb
  install_helm_chart harbor "${MANIFESTS_DIR}/harbor"
  install_helm_chart gitlab "${MANIFESTS_DIR}/gitlab"
  install_helm_chart argocd "${MANIFESTS_DIR}/argocd"
fi

echo "[$(date '+%F %T')] done"