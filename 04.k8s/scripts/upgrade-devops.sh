#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"
NAMESPACE="devops"
TIMEOUT="${HELM_TIMEOUT:-900s}"
WAIT_ARGS="--wait --timeout ${TIMEOUT}"

usage() {
  cat <<USAGE
Usage: $0 [component]

component:
  all      Upgrade all (harbor, gitlab, argocd) [default]
  harbor   Upgrade harbor only
  gitlab   Upgrade gitlab only
  argocd   Upgrade argocd only

Examples:
  $0
  $0 all
  $0 gitlab
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

ensure_namespace() {
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

apply_optional_secret() {
  local chart_dir="$1"
  local candidate

  for candidate in \
    "${chart_dir}/00-secret.yaml" \
    "${chart_dir}/secret.yaml" \
    "${chart_dir}/harbor-secret.yaml"; do
    if [[ -f "${candidate}" ]]; then
      log "Applying secret manifest: ${candidate}"
      kubectl apply -n "${NAMESPACE}" -f "${candidate}"
    fi
  done
}

upgrade_chart() {
  local release="$1"
  local chart_dir="$2"
  local values_file="${chart_dir}/values.yaml"

  if [[ ! -f "${chart_dir}/Chart.yaml" ]]; then
    echo "ERROR: Chart.yaml not found: ${chart_dir}" >&2
    exit 1
  fi

  log "Updating dependencies: ${release}"
  helm dependency update "${chart_dir}" || true

  apply_optional_secret "${chart_dir}"

  log "Upgrading ${release}"
  if [[ -f "${values_file}" ]]; then
    helm upgrade --install "${release}" "${chart_dir}" \
      --namespace "${NAMESPACE}" \
      --create-namespace \
      -f "${values_file}" \
      ${WAIT_ARGS}
  else
    helm upgrade --install "${release}" "${chart_dir}" \
      --namespace "${NAMESPACE}" \
      --create-namespace \
      ${WAIT_ARGS}
  fi
}

show_status() {
  log "Helm releases"
  helm -n "${NAMESPACE}" ls

  log "Services"
  kubectl -n "${NAMESPACE}" get svc -o wide

  log "PVCs"
  kubectl -n "${NAMESPACE}" get pvc

  log "Pods"
  kubectl -n "${NAMESPACE}" get pod -o wide
}

ensure_namespace

case "${COMPONENT}" in
  all)
    upgrade_chart harbor "${MANIFESTS_DIR}/harbor"
    upgrade_chart gitlab "${MANIFESTS_DIR}/gitlab"
    upgrade_chart argocd "${MANIFESTS_DIR}/argocd"
    ;;
  harbor)
    upgrade_chart harbor "${MANIFESTS_DIR}/harbor"
    ;;
  gitlab)
    upgrade_chart gitlab "${MANIFESTS_DIR}/gitlab"
    ;;
  argocd)
    upgrade_chart argocd "${MANIFESTS_DIR}/argocd"
    ;;
  *)
    echo "ERROR: unknown component: ${COMPONENT}" >&2
    usage
    exit 1
    ;;
esac

show_status
log "upgrade complete"
