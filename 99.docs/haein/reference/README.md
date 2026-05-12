# Kubernetes & GitOps 설치 가이드

작성자: haein

---

## 문서 목록

### 1. [Kubernetes 클러스터 설치](01-kubernetes-install.md)

Proxmox VM 4대로 Kubernetes 클러스터 구성

- VM 생성 방법
- kubeadm으로 클러스터 초기화
- Worker 노드 추가
- 클러스터 확인

### 2. [ArgoCD 설치](02-argocd-install.md)

GitOps Continuous Delivery 도구

- ArgoCD 설치 방법
- Web UI 접속
- Git Repository 연결
- Application 배포 테스트

### 3. [GitLab 설치](03-gitlab-install.md)

DevOps 플랫폼 (Git + CI/CD)

- Helm으로 GitLab 설치
- SSH Key 등록
- Project 생성
- CI/CD Pipeline 설정

### 4. [Harbor 설치](05-harbor-install.md)

Container Registry

- Harbor 설치 방법
- Docker 이미지 Push/Pull
- Vulnerability Scanning
- Kubernetes Secret 생성

### 5. [GitLab ↔ ArgoCD 연동](04-gitlab-argocd-workflow.md)

GitOps Workflow 구성

- 자동 배포 설정
- CI/CD Pipeline
- Webhook 연동
- 코드 변경 테스트

---

## 설치 순서

```
1. Kubernetes 설치 (01-kubernetes-install.md)
   └── VM 4대 준비
   └── kosa21: Master node
   └── kosa22-24: Worker nodes
         ↓
2. ArgoCD 설치 (02-argocd-install.md)
   └── devops namespace
   └── GitOps 도구
         ↓
3. GitLab 설치 (03-gitlab-install.md)
   └── Git Repository
   └── CI/CD Pipeline
         ↓
4. Harbor 설치 (05-harbor-install.md)
   └── Container Registry
   └── 이미지 저장
         ↓
5. GitLab ↔ ArgoCD 연동 (04-gitlab-argocd-workflow.md)
   └── 자동 배포 설정
   └── GitOps Workflow
```

---

## Namespace 구성

모든 서비스는 `devops` namespace에 설치:

```bash
kubectl create namespace devops

kubectl get all -n devops
```

**서비스 구성**:
```
devops namespace
  ├── ArgoCD: GitOps CD
  ├── GitLab: Git + CI/CD
  ├── Harbor: Container Registry
  └── Applications: 배포된 앱
```

---

## 전제 조건

### Proxmox 구성

- VM 4대 (kosa21-24)
- rbd-storage (Ceph)
- VLAN 30 (172.16.30.0/24)

### VM 사양

| VM     | CPU | Memory | Disk |
|--------|-----|--------|------|
| kosa21 | 4   | 8GB    | 50GB |
| kosa22 | 4   | 8GB    | 50GB |
| kosa23 | 4   | 8GB    | 50GB |
| kosa24 | 4   | 8GB    | 50GB |

---

## 참고 링크

1. **Kubernetes 설치**: https://github.com/masungil70/docker-kubernetes/tree/main/chapter5
2. **ArgoCD**: https://argo-cd.readthedocs.io/
3. **GitLab**: https://docs.gitlab.com/
4. **Harbor**: https://goharbor.io/docs