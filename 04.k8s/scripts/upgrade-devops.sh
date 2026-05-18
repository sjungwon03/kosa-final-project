#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"
DEVOPS_NAMESPACE="devops"
DATABASE_NAMESPACE="database"
GITEA_NAMESPACE="gitea"
GITLAB_OPERATOR_NAMESPACE="gitlab-system"
TIMEOUT="${HELM_TIMEOUT:-900s}"
WAIT_ARGS="--wait --timeout ${TIMEOUT}"

usage() {
  cat <<USAGE
Usage: $0 [component]

component:
  all      Upgrade all (harbor, gitea, percona-db, argocd) [default]
  harbor   Upgrade harbor only
  gitea       Upgrade gitea only
  percona-db  Upgrade percona-db only
  argocd   Upgrade argocd only
  gitlab-operator Upgrade gitlab-operator only

Examples:
  $0
  $0 all
  $0 gitea
  $0 percona-db
  HELM_TIMEOUT=1200s $0 harbor
  GL_OPERATOR_VERSION=2.9.0 $0 gitlab-operator
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
  local namespace="$1"
  kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

apply_optional_secret() {
  local chart_dir="$1"
  local namespace="$2"
  local candidate

  for candidate in \
    "${chart_dir}/00-secret.yaml" \
    "${chart_dir}/secret.yaml" \
    "${chart_dir}/harbor-secret.yaml"; do
    if [[ -f "${candidate}" ]]; then
      log "Applying secret manifest: ${candidate}"
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

  log "Upgrading ${release}"
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

show_status() {
  for ns in "${DEVOPS_NAMESPACE}" "${DATABASE_NAMESPACE}" "${GITEA_NAMESPACE}" "${GITLAB_OPERATOR_NAMESPACE}"; do
    log "Helm releases (${ns})"
    helm -n "${ns}" ls || true

    log "Services (${ns})"
    kubectl -n "${ns}" get svc -o wide || true

    log "PVCs (${ns})"
    kubectl -n "${ns}" get pvc || true

    log "Pods (${ns})"
    kubectl -n "${ns}" get pod -o wide || true
  done
}

upgrade_gitlab_operator() {
  local operator_dir="${MANIFESTS_DIR}/gitlab-operator"
  local gitlab_cr="${operator_dir}/gitlab.yaml"
  local version="${GL_OPERATOR_VERSION:-2.9.0}"
  local platform="${GL_OPERATOR_PLATFORM:-kubernetes}"
  local manifest_url="https://gitlab.com/api/v4/projects/18899486/packages/generic/gitlab-operator/${version}/gitlab-operator-${platform}-${version}.yaml"

  log "Applying GitLab Operator manifest (${version}/${platform})"
  kubectl apply -f "${manifest_url}"

  if [[ -f "${gitlab_cr}" ]]; then
    log "Applying GitLab CR (${gitlab_cr})"
    kubectl -n "${GITLAB_OPERATOR_NAMESPACE}" apply -f "${gitlab_cr}"
  fi
}

ensure_namespace "${DEVOPS_NAMESPACE}"
ensure_namespace "${DATABASE_NAMESPACE}"
ensure_namespace "${GITEA_NAMESPACE}"
ensure_namespace "${GITLAB_OPERATOR_NAMESPACE}"

case "${COMPONENT}" in
  all)
    upgrade_chart harbor "${MANIFESTS_DIR}/harbor" "${DEVOPS_NAMESPACE}"
    upgrade_chart gitea "${MANIFESTS_DIR}/gitea" "${GITEA_NAMESPACE}"
    upgrade_chart percona-db "${MANIFESTS_DIR}/percona-db" "${DATABASE_NAMESPACE}"
    upgrade_chart argocd "${MANIFESTS_DIR}/argocd" "${DEVOPS_NAMESPACE}"
    log "NOTE: gitlab-operator is optional. Run '$0 gitlab-operator' after setting GL_OPERATOR_VERSION/GL_OPERATOR_PLATFORM."
    ;;
  harbor)
    upgrade_chart harbor "${MANIFESTS_DIR}/harbor" "${DEVOPS_NAMESPACE}"
    ;;
  gitea)
    upgrade_chart gitea "${MANIFESTS_DIR}/gitea" "${GITEA_NAMESPACE}"
    ;;
  percona-db)
    upgrade_chart percona-db "${MANIFESTS_DIR}/percona-db" "${DATABASE_NAMESPACE}"
    ;;
  argocd)
    upgrade_chart argocd "${MANIFESTS_DIR}/argocd" "${DEVOPS_NAMESPACE}"
    ;;
  gitlab-operator)
    upgrade_gitlab_operator
    ;;
  *)
    echo "ERROR: unknown component: ${COMPONENT}" >&2
    usage
    exit 1
    ;;
esac

show_status
log "upgrade complete"
