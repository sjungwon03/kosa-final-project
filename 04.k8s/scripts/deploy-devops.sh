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

DEVOPS_NAMESPACE="devops"
DATABASE_NAMESPACE="database"
GITEA_NAMESPACE="gitea"

create_namespace() {
  local namespace=$1
  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
}

install_helm_chart() {
  local name=$1
  local chart_dir=$2
  local namespace=$3
  local values_file="${chart_dir}/values.yaml"
  
  echo "[$(date '+%F %T')] Installing $name with Helm..."
  
  # Secret 배포 (있는 경우)
  if [ -f "${chart_dir}/00-secret.yaml" ]; then
    kubectl apply -f "${chart_dir}/00-secret.yaml" -n "$namespace"
  fi
  
  if [ ! -f "${chart_dir}/Chart.yaml" ]; then
    echo "ERROR: Chart.yaml not found in ${chart_dir}"
    exit 1
  fi

  # Gitea chart v12+ no longer supports actions/actRunner in the main chart.
  if [[ "$name" == "gitea" ]] && grep -Eq '^[[:space:]]*(actions:|actRunner:)' "$values_file"; then
    echo "ERROR: gitea values.yaml contains deprecated keys: actions/actRunner."
    echo "       Remove them from ${values_file} and deploy actions with a dedicated chart."
    exit 1
  fi
  
  helm dependency update "$chart_dir" || true
  
  if [ -f "$values_file" ]; then
    helm $ACTION $name "$chart_dir" \
      --namespace "$namespace" \
      -f "$values_file" \
      --reset-values \
      --timeout 600s
  else
    helm $ACTION $name "$chart_dir" \
      --namespace "$namespace" \
      --reset-values \
      --timeout 600s
  fi
}

create_namespace "$DEVOPS_NAMESPACE"
create_namespace "$GITEA_NAMESPACE"

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
      install_helm_chart harbor "${MANIFESTS_DIR}/harbor" "$DEVOPS_NAMESPACE"
      ;;
    percona-db)
      create_namespace "$DATABASE_NAMESPACE"
      install_helm_chart percona-db "${MANIFESTS_DIR}/percona-db" "$DATABASE_NAMESPACE"
      ;;
    gitea)
      install_helm_chart gitea "${MANIFESTS_DIR}/gitea" "$GITEA_NAMESPACE"
      ;;
    argocd)
      install_helm_chart argocd "${MANIFESTS_DIR}/argocd" "$DEVOPS_NAMESPACE"
      ;;
    *)
      echo "ERROR: Unknown component: $COMPONENT"
      exit 1
      ;;
  esac
else
  create_namespace "$DATABASE_NAMESPACE"
  create_namespace "$GITEA_NAMESPACE"
  install_helm_chart harbor "${MANIFESTS_DIR}/harbor" "$DEVOPS_NAMESPACE"
  install_helm_chart gitea "${MANIFESTS_DIR}/gitea" "$GITEA_NAMESPACE"
  install_helm_chart percona-db "${MANIFESTS_DIR}/percona-db" "$DATABASE_NAMESPACE"
  install_helm_chart argocd "${MANIFESTS_DIR}/argocd" "$DEVOPS_NAMESPACE"
fi

echo "[$(date '+%F %T')] done"
