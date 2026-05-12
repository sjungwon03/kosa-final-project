# GitLab ↔ ArgoCD GitOps Workflow (초보자용)

작성자: haein

---

## 이 가이드로 무엇을 할 수 있나요?

GitLab에 코드를 push → 자동으로 Kubernetes에 배포

**Workflow**:
```
Git Push → GitLab CI/CD Build → Harbor 이미지 Push → ArgoCD 자동 Sync → Kubernetes 배포
```

---

## 전제 조건

이미 설치된 서비스:
- GitLab → 03-gitlab-install.md
- ArgoCD → 02-argocd-install.md
- Harbor → 05-harbor-install.md

---

## Step 1: GitLab Project 준비

### 1-1. Project 생성

1. GitLab Web UI → Projects → New Project
2. Project name: `my-k8s-app`
3. Visibility: Private
4. Initialize with README: ☑
5. Create project

### 1-2. Clone

```bash
git clone https://gitlab.kosa.local/root/my-k8s-app.git
cd my-k8s-app
```

---

## Step 2: Kubernetes Manifests 생성

### 2-1. manifests 디렉토리 생성

```bash
mkdir -p manifests
```

### 2-2. deployment.yaml 생성

```bash
cat > manifests/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: devops
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      imagePullSecrets:
      - name: harbor-secret
      containers:
      - name: my-app
        image: harbor.kosa.local/devops/my-app:latest
        ports:
        - containerPort: 80
EOF
```

### 2-3. service.yaml 생성

```bash
cat > manifests/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: devops
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: my-app
EOF
```

---

## Step 3: ArgoCD Application 생성

### 3-1. Application YAML 생성

```bash
cat > argocd-application.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: devops
spec:
  project: default
  source:
    repoURL: https://gitlab.kosa.local/root/my-k8s-app.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: devops
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

### 3-2. Application 적용

```bash
kubectl apply -f argocd-application.yaml

# 확인
kubectl get application -n devops
```

### 3-3. ArgoCD Web UI 확인

1. https://localhost:8080 (ArgoCD)
2. Applications → my-app
3. Status: OutOfSync (Sync 필요)

---

## Step 4: Harbor Secret 생성

### 4-1. Harbor Robot Account 생성

1. Harbor Web UI → Projects → devops → Robot Accounts
2. Add Robot Account
3. Name: `gitlab-ci`
4. Permissions: Read/Write
5. Save → Token 복사

### 4-2. Kubernetes Secret 생성

```bash
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.kosa.local \
  --docker-username=robot\$gitlab-ci \
  --docker-password=<token> \
  --namespace devops
```

---

## Step 5: GitLab CI/CD 설정

### 5-1. Harbor Token 등록 (GitLab)

1. GitLab Web UI → Project → Settings → CI/CD → Variables
2. Add Variable
   - Key: `HARBOR_PASSWORD`
   - Value: <Harbor Robot Account Token>
   - Mask variable: ☑
3. Add Variable

### 5-2. .gitlab-ci.yml 생성

```bash
cat > .gitlab-ci.yml <<EOF
stages:
  - build
  - deploy

variables:
  HARBOR_URL: harbor.kosa.local
  HARBOR_PROJECT: devops
  IMAGE_NAME: my-app

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u robot\$gitlab-ci -p $HARBOR_PASSWORD $HARBOR_URL
    - docker build -t $HARBOR_URL/$HARBOR_PROJECT/$IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $HARBOR_URL/$HARBOR_PROJECT/$IMAGE_NAME:$CI_COMMIT_SHA
  only:
    - main

deploy:
  stage: deploy
  image: alpine:latest
  script:
    - apk add --no-cache git
    - git config user.name "GitLab CI"
    - git config user.email "ci@gitlab.kosa.local"
    - sed -i "s|image:.*|image: $HARBOR_URL/$HARBOR_PROJECT/$IMAGE_NAME:$CI_COMMIT_SHA|" manifests/deployment.yaml
    - git add manifests/deployment.yaml
    - git commit -m "Update image to $CI_COMMIT_SHA"
    - git push https://oauth2:$CI_JOB_TOKEN@gitlab.kosa.local/root/my-k8s-app.git HEAD:main
  only:
    - main
EOF
```

---

## Step 6: Dockerfile 생성

```bash
cat > Dockerfile <<EOF
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EOF

cat > index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>My App</title>
</head>
<body>
    <h1>Hello from Kubernetes!</h1>
    <p>Version: 1.0</p>
</body>
</html>
EOF
```

---

## Step 7: Push 및 배포 테스트

### 7-1. 모든 파일 Push

```bash
git add .
git commit -m "Initial commit with GitOps setup"
git push origin main
```

### 7-2. GitLab Pipeline 확인

1. GitLab Web UI → CI/CD → Pipelines
2. Pipeline 실행 확인
3. build job → Docker 이미지 push 확인
4. deploy job → manifest 업데이트 확인

### 7-3. ArgoCD Sync 확인

1. ArgoCD Web UI → Applications → my-app
2. Synced 상태 확인 (자동 sync)

### 7-4. Kubernetes 확인

```bash
kubectl get pods -n devops -l app=my-app

# 출력:
# NAME         READY   STATUS
# my-app-xxx   1/1     Running
# my-app-yyy   1/1     Running
```

---

## Step 8: 코드 변경 테스트

### 8-1. HTML 수정

```bash
vim index.html

# Version 변경
<p>Version: 2.0</p>
```

### 8-2. Push

```bash
git add index.html
git commit -m "Update version to 2.0"
git push origin main
```

### 8-3. 자동 배포 확인

1. GitLab Pipeline 실행
2. ArgoCD Sync 실행 (자동)
3. Pod 재생성 확인

```bash
kubectl get pods -n devops -l app=my-app

# 새 Pod 생성 확인
```

---

## Webhook 설정 (Instant Sync)

ArgoCD가 Git push를 즉시 감지하도록 설정합니다.

### 9-1. Webhook URL 확인

```bash
# ArgoCD Webhook URL
https://argocd.kosa.local/api/webhook
```

### 9-2. GitLab Webhook 추가

1. GitLab → Project → Settings → Webhooks
2. URL: `https://argocd.kosa.local/api/webhook`
3. Trigger: Push events
4. Add webhook

### 9-3. Test

1. Push events → Test → Push events
2. Hook executed successfully 확인

---

## 문제 해결

### Pipeline 실패

```bash
# GitLab Runner 로그
kubectl logs -n devops deployment/gitlab-runner

# Harbor 로그인 실패면:
# Variable HARBOR_PASSWORD 확인
```

### ArgoCD OutOfSync

```bash
# Manual sync
argocd app sync my-app

# Git repository 확인
argocd app get my-app
```

### Pod Image Pull 실패

```bash
# Secret 확인
kubectl describe secret harbor-secret -n devops

# Secret 재생성
kubectl delete secret harbor-secret -n devops
kubectl create secret docker-registry harbor-secret ...
```

---

## 다음 단계

1. Application 기능 추가
2. Multi-environment 배포 (dev, prod)
3. Helm Chart 사용