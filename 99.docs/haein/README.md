# Kubernetes & GitOps 테스트 환경 설치 가이드

작성자: haein

---

## 테스트 환경

**테스트 노드**: 192.168.34.2 (단일 노드)

**설치 서비스**:
- Kubernetes (kubeadm)
- ArgoCD (GitOps CD)
- GitLab (Git + CI/CD)
- Harbor (Container Registry)

**Namespace**: devops

---

## 문서 목록

### 1. [Kubernetes 설치](01-kubernetes-install.md)

단일 노드 Kubernetes 클러스터 구성

- 192.168.34.2에서 kubeadm 초기화
- Master 노드에 Pod 배포 허용
- Flannel 네트워크 플러그인
- devops namespace 생성

### 2. [ArgoCD 설치](02-argocd-install.md)

GitOps Continuous Delivery 도구

- ArgoCD YAML 생성
- Ingress YAML 생성
- Application YAML 생성
- Web UI 접속

### 3. [GitLab 설치](03-gitlab-install.md)

Git + CI/CD 플랫폼

- Helm values.yaml 생성
- GitLab 설치
- SSH Key 등록
- CI/CD Pipeline

### 4. [Harbor 설치](05-harbor-install.md)

Container Registry

- Harbor values.yaml 생성
- Harbor 설치
- Docker 로그인
- 이미지 Push/Pull

### 5. [GitLab ↔ ArgoCD 연동](04-gitlab-argocd-workflow.md)

GitOps Workflow 구성

- Manifests YAML 생성
- ArgoCD Application YAML
- .gitlab-ci.yml 생성
- 자동 배포 테스트

---

## 설치 순서

```
1. Kubernetes 설치 (01-kubernetes-install.md)
   └── ssh kosa@192.168.34.2
   └── kubeadm init
   └── devops namespace 생성
         ↓
2. ArgoCD 설치 (02-argocd-install.md)
   └── ~/k8s-yamls/argocd-install.yaml
   └── ~/k8s-yamls/argocd-ingress.yaml
         ↓
3. GitLab 설치 (03-gitlab-install.md)
   └── ~/k8s-yamls/gitlab/values.yaml
         ↓
4. Harbor 설치 (05-harbor-install.md)
   └── ~/k8s-yamls/harbor/values.yaml
   └── ~/k8s-yamls/harbor-secret.yaml
         ↓
5. GitLab ↔ ArgoCD 연동 (04-gitlab-argocd-workflow.md)
   └── manifests/deployment.yaml
   └── manifests/service.yaml
   └── argocd-my-app.yaml
   └── .gitlab-ci.yml
```

---

## YAML 파일 목록

```
~/k8s-yamls/
├── argocd-install.yaml       # ArgoCD 설치 (URL)
├── argocd-ingress.yaml       # ArgoCD Ingress
├── argocd-my-app.yaml        # ArgoCD Application
├── gitlab/
│   └── values.yaml           # GitLab Helm values
├── harbor/
│   ├── values.yaml           # Harbor Helm values
│   └── harbor-secret.yaml    # Harbor registry secret
└── manifests/
    ├── deployment.yaml        # Deployment
    └── service.yaml           # Service
```

---

## Web UI 접속

| Service | URL |
|---------|-----|
| ArgoCD  | https://argocd.192.168.34.2.nip.io |
| GitLab  | https://gitlab.192.168.34.2.nip.io |
| Harbor  | https://harbor.192.168.34.2.nip.io |

---

## 참고 링크

1. **Kubernetes 설치**: https://github.com/masungil70/docker-kubernetes/tree/main/chapter5
2. **ArgoCD**: https://argo-cd.readthedocs.io/
3. **GitLab**: https://docs.gitlab.com/
4. **Harbor**: https://goharbor.io/docs