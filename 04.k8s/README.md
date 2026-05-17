# Platform 서비스 배포

Helm chart 기반 DevOps 서비스 배포

`MetalLB`와 `Ceph CSI/StorageClass`는 `03.ansible/workspace/playbooks/k8s.yml`에서 관리합니다.

## 구조

```text
04.k8s/
├── manifests/
│   ├── metallb/             # MetalLB LoadBalancer
│   ├── storage/             # Ceph RBD StorageClass/Secret
│   ├── harbor/              # Harbor 컨테이너 레지스트리 (Helm)
│   ├── gitea/               # Gitea + Actions Runner (Helm)
│   ├── percona-db/          # Percona Operator + PXC (Helm)
│   ├── argocd/              # ArgoCD GitOps (Helm)
│   ├── gitlab-operator/     # GitLab Operator + GitLab CR (Manifest)
│   ├── eks/                 # EKS 클라우드 버스팅용
│   └── namespace.yaml
└── scripts/
    ├── deploy-devops.sh
    └── upgrade-devops.sh
```

## 배포

```bash
# 모든 DevOps 서비스 설치 (Harbor + Gitea + Percona DB + ArgoCD)
./scripts/deploy-devops.sh install

# 개별 서비스 설치
./scripts/deploy-devops.sh install harbor
./scripts/deploy-devops.sh install gitea
./scripts/deploy-devops.sh install percona-db
./scripts/deploy-devops.sh install argocd
GL_OPERATOR_VERSION=2.9.0 ./scripts/deploy-devops.sh install gitlab-operator

# 개별 서비스 삭제
./scripts/deploy-devops.sh uninstall percona-db
```

## 업그레이드

```bash
# 전체 업그레이드
./scripts/upgrade-devops.sh

# 개별 업그레이드
./scripts/upgrade-devops.sh harbor
./scripts/upgrade-devops.sh gitea
./scripts/upgrade-devops.sh percona-db
./scripts/upgrade-devops.sh argocd
GL_OPERATOR_VERSION=2.9.0 ./scripts/upgrade-devops.sh gitlab-operator
```

## LoadBalancer IP 확인

```bash
kubectl get svc -n devops
kubectl get svc -n devops | grep -E 'harbor|argo'
kubectl get svc -n gitea | grep gitea
kubectl get svc -n database | grep percona
```

## Percona DB 진입점

```text
# 클러스터 내부
percona-db-pxc-db-haproxy.database.svc.cluster.local:3306

# 클러스터 외부
kubectl -n database get svc | grep percona-db
```

## DNS 등록 예시

```text
harbor.mgmt.local    IN A    <HARBOR_LB_IP>
gitea.mgmt.local     IN A    <GITEA_LB_IP>
argocd.mgmt.local    IN A    <ARGOCD_LB_IP>
```

## 기본 계정 정보

| 서비스 | DNS               | 계정 |
|--------|-------------------|------|
| Harbor | harbor.mgmt.local | admin / values.yaml에 설정된 값 |
| Gitea  | gitea.mgmt.local  | gitea_admin / values.yaml에 설정된 값 |
| Percona DB | 내부/외부 Service | root / values.yaml에 설정된 값 |
| ArgoCD | argocd.mgmt.local | admin |
