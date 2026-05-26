# GitLab ↔ ArgoCD GitOps Workflow (테스트 노드)

작성자: haein

---

## 테스트 환경

**노드**: 192.168.34.2
**Namespace**: devops

---

## 전제 조건

설치된 서비스:
- ArgoCD → 02-argocd-install.md
- GitLab → 03-gitlab-install.md
- Harbor → 05-harbor-install.md

---

## Step 1: GitLab Project 생성

### 1-1. Web UI에서

1. GitLab 접속: `https://gitlab.192.168.34.2.nip.io`
2. Projects → New Project
3. Project name: `my-k8s-app`
4. Initialize with README: ☑
5. Create

### 1-2. Clone

```bash
git clone https://gitlab.192.168.34.2.nip.io/root/my-k8s-app.git
cd my-k8s-app
```

---

## Step 2: Kubernetes Manifests YAML 생성

### 2-1. manifests 디렉토리

```bash
mkdir -p manifests
cd manifests

cat > deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: devops
spec:
  replicas: 1
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
        image: harbor.192.168.34.2.nip.io/devops/my-app:latest
        ports:
        - containerPort: 80
EOF

cat > service.yaml <<EOF
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

## Step 3: ArgoCD Application YAML 생성

### 3-1. Application YAML

```bash
cd ~/k8s-yamls

cat > argocd-my-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: devops
spec:
  project: default
  source:
    repoURL: https://gitlab.192.168.34.2.nip.io/root/my-k8s-app.git
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

kubectl apply -f argocd-my-app.yaml
```

---

## Step 4: Dockerfile 생성

```bash
cd ~/my-k8s-app

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

## Step 5: .gitlab-ci.yml 생성

```bash
cat > .gitlab-ci.yml <<EOF
stages:
  - build
  - deploy

variables:
  HARBOR_URL: harbor.192.168.34.2.nip.io
  HARBOR_PROJECT: devops
  IMAGE_NAME: my-app

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u admin -p Harbor12345 $HARBOR_URL
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
    - git config user.email "ci@gitlab.192.168.34.2.nip.io"
    - sed -i "s|image:.*my-app.*|image: $HARBOR_URL/$HARBOR_PROJECT/$IMAGE_NAME:$CI_COMMIT_SHA|" manifests/deployment.yaml
    - git add manifests/deployment.yaml
    - git commit -m "Update image to $CI_COMMIT_SHA"
    - git push https://oauth2:$CI_JOB_TOKEN@gitlab.192.168.34.2.nip.io/root/my-k8s-app.git HEAD:main
  only:
    - main
EOF
```

---

## Step 6: Push 및 테스트

### 6-1. 모든 파일 Push

```bash
git add .
git commit -m "Initial GitOps setup"
git push origin main
```

### 6-2. GitLab Pipeline 확인

1. GitLab → CI/CD → Pipelines
2. Pipeline 실행 확인
3. build job → Docker 이미지 push
4. deploy job → manifest 업데이트

### 6-3. ArgoCD 확인

1. ArgoCD → Applications → my-app
2. Synced 상태 확인

### 6-4. Pod 확인

```bash
kubectl get pods -n devops -l app=my-app
```

---

## Step 7: Webhook 설정

### 7-1. GitLab Webhook

1. GitLab → Settings → Webhooks
2. URL: `https://argocd.192.168.34.2.nip.io/api/webhook`
3. Trigger: Push events
4. Add webhook

---

## 참고 링크

1. **ArgoCD**: https://argo-cd.readthedocs.io/
2. **GitLab**: https://docs.gitlab.com/
3. **Harbor**: https://goharbor.io/docs