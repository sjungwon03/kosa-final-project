#!/bin/bash
# DevOps 서비스 업그레이드 스크립트 (Harbor, Gitea, Percona DB, ArgoCD)
# GitLab은 install-gitlab.sh로 별도 관리

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"
TIMEOUT="${HELM_TIMEOUT:-900s}"
WAIT_ARGS="--wait --timeout ${TIMEOUT}"

usage() {
  cat <<USAGE
Usage: $0 [component]

component:
  all        전체 업그레이드 (harbor, gitea, percona-db, argocd) [기본값]
  harbor     harbor only
  gitea      gitea only
  percona-db percona-db only
  argocd     argocd only

Examples:
  $0
  $0 gitea
  HELM_TIMEOUT=1200s $0 harbor
USAGE
}

COMPONENT="${1:-all}"

if [[ "${COMPONENT}" == "-h" || "${COMPONENT}" == "--help" ]]; then
  usage
  exit 0
fi

log() {
  echo "[$(date '+%F %T')] $*"
}

apply_optional_secret() {
  local chart_dir="$1"
  local namespace="$2"
  for candidate in "${chart_dir}/00-secret.yaml" "${chart_dir}/secret.yaml"; do
    if [[ -f "${candidate}" ]]; then
      log "Applying secret: ${candidate}"
      kubectl apply -n "${namespace}" -f "${candidate}"
    fi
  done
}

upgrade_chart() {
  local release="$1"
  local chart_dir="$2"
  local namespace="$3"
  local values_file="${chart_dir}/values.yaml"

  if [[ ! -f "${chart_dir}/Chart.yaml" ]]; then
    echo "ERROR: Chart.yaml not found: ${chart_dir}" >&2
    exit 1
  fi

  log "Updating dependencies: ${release}"
  helm dependency update "${chart_dir}" || true

  apply_optional_secret "${chart_dir}" "${namespace}"

  log "Upgrading ${release} in namespace ${namespace}"
  if [[ -f "${values_file}" ]]; then
    helm upgrade --install "${release}" "${chart_dir}" \
      --namespace "${namespace}" \
      --create-namespace \
      -f "${values_file}" \
      --reset-values \
      ${WAIT_ARGS}
  else
    helm upgrade --install "${release}" "${chart_dir}" \
      --namespace "${namespace}" \
      --create-namespace \
      --reset-values \
      ${WAIT_ARGS}
  fi
}

case "${COMPONENT}" in
  all)
    upgrade_chart harbor    "${MANIFESTS_DIR}/harbor"     "harbor"
    upgrade_chart gitea     "${MANIFESTS_DIR}/gitea"      "gitea"
    upgrade_chart percona-db "${MANIFESTS_DIR}/percona-db" "percona-db"
    upgrade_chart argocd    "${MANIFESTS_DIR}/argocd"     "argocd"
    ;;
  harbor)
    upgrade_chart harbor    "${MANIFESTS_DIR}/harbor"     "harbor"
    ;;
  gitea)
    upgrade_chart gitea     "${MANIFESTS_DIR}/gitea"      "gitea"
    ;;
  percona-db)
    upgrade_chart percona-db "${MANIFESTS_DIR}/percona-db" "percona-db"
    ;;
  argocd)
    upgrade_chart argocd    "${MANIFESTS_DIR}/argocd"     "argocd"
    ;;
  *)
    echo "ERROR: unknown component: ${COMPONENT}" >&2
    usage
    exit 1
    ;;
esac

log "upgrade complete"
