# Platform 서비스 배포

Helm chart 기반 서비스 배포 (MetalLB LoadBalancer)

## 구조

```
04.k8s/
├── manifests/
│   ├── metallb/             # MetalLB LoadBalancer
│   │   ├── 01-ip-address-pool.yaml
│   │   └── 02-metallb.yaml
│   ├── harbor/              # Harbor 컨테이너 레지스트리
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   ├── gitlab/              # GitLab CE Git 저장소
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   ├── argocd/              # ArgoCD GitOps
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   ├── eks/                 # EKS 클라우드 버스팅용
│   └── namespace.yaml
├── argocd-apps/             # ArgoCD Application 정의
│   ├── harbor.yaml
│   ├── gitlab.yaml
│   └── README.md
├── scripts/
│   └── deploy-devops.sh
└── README.md
```

## 배포

```bash
# 모든 서비스 설치 (MetalLB + Harbor + GitLab + ArgoCD)
./scripts/deploy-devops.sh install

# 개별 서비스 설치
./scripts/deploy-devops.sh install metallb
./scripts/deploy-devops.sh install harbor
./scripts/deploy-devops.sh install gitlab
./scripts/deploy-devops.sh install argocd

# 서비스 삭제
./scripts/deploy-devops.sh uninstall harbor
```

## LoadBalancer IP 확인

```bash
# MetalLB IP Pool: 172.16.30.200-172.16.30.210
kubectl get svc -n platform

# Harbor LoadBalancer IP
kubectl get svc harbor -n platform

# GitLab LoadBalancer IP
kubectl get svc gitlab-webservice -n platform
kubectl get svc gitlab-gitlab-shell -n platform

# ArgoCD LoadBalancer IP
kubectl get svc argo-cd-argocd-server -n platform
```

## DNS 등록

MetalLB에서 할당된 IP를 DNS 서버에 A 레코드로 등록:

```
harbor.mgmt.local    IN A    <HARBOR_LB_IP>
gitlab.mgmt.local    IN A    <GITLAB_LB_IP>
argocd.mgmt.local    IN A    <ARGOCD_LB_IP>
```

## 서비스 정보

| 서비스   | DNS                   | 계정             |
|----------|----------------------|------------------|
| Harbor   | harbor.mgmt.local    | admin/admin123   |
| GitLab   | gitlab.mgmt.local    | root/GitLabRoot123 |
| ArgoCD   | argocd.mgmt.local    | admin            |

## ArgoCD GitOps

ArgoCD Application 배포:
```bash
kubectl apply -f argocd-apps/harbor.yaml
kubectl apply -f argocd-apps/gitlab.yaml
```