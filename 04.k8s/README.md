# Platform 서비스 배포

Helm chart 기반 서비스 배포 (MetalLB LoadBalancer)

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
│   ├── eks/                 # EKS 클라우드 버스팅용
│   └── namespace.yaml
└── scripts/
    ├── deploy-devops.sh
    └── upgrade-devops.sh
```

## 배포

```bash
# 모든 서비스 설치 (MetalLB + Ceph Storage + Harbor + Gitea + Percona DB + ArgoCD)
./scripts/deploy-devops.sh install

# 개별 서비스 설치
./scripts/deploy-devops.sh install metallb
./scripts/deploy-devops.sh install storage
./scripts/deploy-devops.sh install harbor
./scripts/deploy-devops.sh install gitea
./scripts/deploy-devops.sh install percona-db
./scripts/deploy-devops.sh install argocd

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
```

## LoadBalancer IP 확인

```bash
kubectl get svc -n devops
kubectl get svc -n devops | grep -E 'harbor|gitea|percona|argo'
```

## Percona DB 진입점

```text
# 클러스터 내부
percona-db-pxc-db-haproxy.devops.svc.cluster.local:3306

# 클러스터 외부
kubectl -n devops get svc | grep percona-db
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
