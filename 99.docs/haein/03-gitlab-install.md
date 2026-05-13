# GitLab 설치 가이드 (테스트 노드)

작성자: haein

---

## 테스트 환경

**노드**: 192.168.34.2
**Namespace**: devops

---

## Step 1: Helm Repository 추가

```bash
ssh kosa@192.168.34.2

helm repo add gitlab https://charts.gitlab.io/
helm repo update
```

---

## Step 2: GitLab values YAML 생성

### 2-1. values.yaml 파일

```bash
mkdir -p ~/k8s-yamls/gitlab
cd ~/k8s-yamls/gitlab

cat > values.yaml <<EOF
global:
  hosts:
    domain: 192.168.34.2.nip.io
    gitlab:
      name: gitlab.192.168.34.2.nip.io
  ingress:
    configureCertmanager: false
    class: nginx

gitlab-runner:
  install: false

nginx-ingress:
  enabled: false

registry:
  enabled: false

gitlab:
  webservice:
    minReplicas: 1
    maxReplicas: 1
EOF
```

---

## Step 3: GitLab 설치

### 3-1. Helm 설치

```bash
helm install gitlab gitlab/gitlab \
  --namespace devops \
  --values values.yaml \
  --timeout 600s
```

### 3-2. 설치 확인

```bash
kubectl get pods -n devops | grep gitlab

# 10-15분 대기
kubectl wait --for=condition=ready pod -l app=webservice -n devops --timeout=600s
```

---

## Step 4: 비밀번호 확인

```bash
kubectl get secret -n devops gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d
```

**비밀번호 저장!**

---

## Step 5: Web UI 접속

```
https://gitlab.192.168.34.2.nip.io

Username: root
Password: <Step 4에서 확인한 비밀번호>
```

### Port-forward (Ingress 없을 때)

```bash
kubectl port-forward svc/gitlab-webservice-default -n devops 8080:8080 --address 192.168.34.2 &

# 접속: http://192.168.34.2:8080
```

---

## Step 6: SSH Key 등록

### 6-1. SSH Key 생성

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
cat ~/.ssh/id_ed25519.pub
```

### 6-2. GitLab에 등록

1. Web UI → User Settings → SSH Keys
2. Key 입력
3. Add key

---

## Step 7: Project 생성

### 7-1. Web UI에서

1. Projects → New Project → Create blank project
2. Project name: `my-app`
3. Visibility: Private
4. Initialize with README: ☑
5. Create

### 7-2. Clone 테스트

```bash
git clone git@gitlab.192.168.34.2.nip.io:root/my-app.git
cd my-app

echo "# My App" > README.md
git add .
git commit -m "Initial commit"
git push origin main
```

---

## Step 8: CI/CD YAML 생성

### 8-1. .gitlab-ci.yml

```bash
cat > .gitlab-ci.yml <<EOF
stages:
  - build
  - test

build:
  stage: build
  script:
    - echo "Building application..."

test:
  stage: test
  script:
    - echo "Running tests..."
EOF

git add .gitlab-ci.yml
git commit -m "Add CI/CD pipeline"
git push origin main
```

### 8-2. Pipeline 확인

1. Web UI → CI/CD → Pipelines
2. Pipeline 실행 확인

---

## 참고 링크

1. **GitLab 공식 문서**: https://docs.gitlab.com/
2. **Helm Chart**: https://docs.gitlab.com/charts/

---

## 다음 단계

1. Harbor 설치 → 05-harbor-install.md
2. GitLab ↔ ArgoCD 연동 → 04-gitlab-argocd-workflow.md