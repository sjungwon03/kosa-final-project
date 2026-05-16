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

NAMESPACE="platform"

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
  
  if [ -f "${chart_dir}/Chart.yaml" ]; then
    echo "[$(date '+%F %T')] Installing $name with Helm (from chart dir)..."
    helm dependency update "$chart_dir" || true
    helm $ACTION $name "$chart_dir" \
      --namespace $NAMESPACE \
      --timeout 600s \
      $( [ -f "${chart_dir}/values.yaml" ] && echo "-f ${chart_dir}/values.yaml" )
  else
    echo "[$(date '+%F %T')] Direct Helm install for $name..."
    case $name in
      harbor)
        helm $ACTION harbor harbor/harbor \
          --namespace $NAMESPACE \
          --set expose.type=loadBalancer \
          --set expose.tls.enabled=false \
          --set externalURL=http://harbor.mgmt.local \
          --set harborAdminPassword=admin123 \
          --set persistence.enabled=true \
          --timeout 300s
        ;;
      gitlab)
        helm $ACTION gitlab gitlab/gitlab \
          --namespace $NAMESPACE \
          --set global.hosts.domain=mgmt.local \
          --set global.hosts.https=false \
          --set global.initialRootPassword=GitLabRoot123 \
          --set gitlab.webservice.replicaCount=1 \
          --set gitlab.webservice.service.type=LoadBalancer \
          --set gitlab.sidekiq.replicaCount=1 \
          --set gitlab.gitlab-shell.replicaCount=1 \
          --set gitlab.gitlab-shell.service.type=LoadBalancer \
          --set nginx-ingress.enabled=false \
          --set prometheus.install=false \
          --set certmanager.installCRDs=false \
          --set nodeSelector.role=platform \
          --timeout 600s \
          --version 7.0.0
        ;;
      argocd)
        helm $ACTION argocd argo/argo-cd \
          --namespace $NAMESPACE \
          --set controller.replicas=1 \
          --set server.replicas=1 \
          --set server.extraArgs[0]=--insecure \
          --set server.service.type=LoadBalancer \
          --set repoServer.replicas=1 \
          --set configs.params.server.insecure=true \
          --set nodeSelector.role=platform \
          --timeout 300s \
          --version 5.46.0
        ;;
    esac
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