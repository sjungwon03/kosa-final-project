# GitLab 설치 가이드 (초보자용)

작성자: haein

---

## GitLab이 무엇인가요?

GitLab은 DevOps 플랫폼입니다.

**기능**:
- Git Repository: 코드 저장
- CI/CD Pipeline: 자동 빌드/배포
- Issue Tracking: 프로젝트 관리
- Container Registry: Docker 이미지 저장
- Web IDE: 웹에서 코드 편집

---

## Step 1: Namespace 확인

```bash
# kosa21에서 실행
kubectl get namespace devops

# 없으면 생성
kubectl create namespace devops
```

---

## Step 2: Helm Repository 추가

### 2-1. Repository 추가

```bash
helm repo add gitlab https://charts.gitlab.io/
helm repo update
```

### 2-2. 확인

```bash
helm repo list

# 출력:
# NAME    URL
# gitlab  https://charts.gitlab.io/
```

---

## Step 3: GitLab 설치

### 3-1. 기본 설치 (테스트용)

```bash
helm install gitlab gitlab/gitlab \
  --namespace devops \
  --set global.hosts.domain=kosa.local \
  --set global.hosts.gitlab.name=gitlab.kosa.local \
  --set gitlab-runner.install=false \
  --timeout 600s
```

**설치 시간**: 10-15분

### 3-2. 설치 확인

```bash
kubectl get pods -n devops

# 출력 (모든 Pod Running):
# NAME                      READY   STATUS
# gitlab-webservice-xxx     1/1     Running
# gitlab-sidekiq-xxx        1/1     Running
# gitlab-task-runner-xxx    1/1     Running
# gitlab-gitaly-xxx         1/1     Running
```

### 3-3. Pod Running 대기

```bash
kubectl wait --for=condition=ready pod -l app=webservice -n devops --timeout=600s
```

---

## Step 4: 초기 비밀번호 확인

### 4-1. Root 비밀번호

```bash
kubectl get secret -n devops gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d

# 출력 예시:
# 4k9L2mN7pQ3x
```

**이 비밀번호를 저장하세요!**

---

## Step 5: Web UI 접속

### 5-1. Port-forward

```bash
kubectl port-forward svc/gitlab-webservice-default -n devops 8080:8080 &
```

### 5-2. Browser 접속

```
http://localhost:8080
```

### 5-3. 로그인

- Username: `root`
- Password: Step 4에서 확인한 비밀번호

---

## Step 6: 비밀번호 변경

1. Web UI 로그인
2. Admin Area → Settings → Account and Limits
3. Change password
4. 새 비밀번호 입력
5. Save

---

## Step 7: SSH Key 등록

Git push/pull을 위해 SSH Key가 필요합니다.

### 7-1. SSH Key 생성

```bash
# Terminal에서
ssh-keygen -t ed25519 -C "your-email@example.com"

# Key 위치: ~/.ssh/id_ed25519
```

### 7-2. Public Key 확인

```bash
cat ~/.ssh/id_ed25519.pub

# 출력:
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... your-email@example.com
```

### 7-3. GitLab에 등록

1. Web UI → User Settings → SSH Keys
2. Key 입력 (위 출력값 복사)
3. Title: `my-laptop`
4. Add key

---

## Step 8: Project 생성

### 8-1. Web UI에서

1. Projects → Create blank project
2. Project name: `my-app`
3. Visibility level: `Private`
4. Initialize repository with README: ☑
5. Create project

### 8-2. Project URL 확인

```
https://gitlab.kosa.local/root/my-app.git
```

---

## Step 9: Git Clone 테스트

### 9-1. Clone

```bash
git clone git@gitlab.kosa.local:root/my-app.git

# 또는 HTTPS
git clone https://gitlab.kosa.local/root/my-app.git
```

### 9-2. 파일 수정

```bash
cd my-app

# 파일 생성
echo "# My First App" > README.md

# Commit
git add README.md
git commit -m "Update README"

# Push
git push origin main
```

### 9-3. Web UI 확인

1. Projects → my-app
2. README.md 변경 확인

---

## Step 10: CI/CD Pipeline 설정

### 10-1. .gitlab-ci.yml 파일 생성

```bash
cd my-app

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
```

### 10-2. Push

```bash
git add .gitlab-ci.yml
git commit -m "Add CI/CD pipeline"
git push origin main
```

### 10-3. Pipeline 확인

1. Web UI → CI/CD → Pipelines
2. Pipeline 실행 확인
3. Jobs 클릭 → Log 확인

---

## Step 11: Container Registry 사용

GitLab에 Docker 이미지를 push합니다.

### 11-1. Registry 로그인

```bash
docker login registry.kosa.local

Username: root
Password: <GitLab 비밀번호>
```

### 11-2. 이미지 Push

```bash
# 이미지 생성
docker build -t my-app:latest .

# Tag
docker tag my-app:latest registry.kosa.local/root/my-app:latest

# Push
docker push registry.kosa.local/root/my-app:latest
```

### 11-3. Web UI 확인

1. Projects → my-app → Deploy → Container Registry
2. 이미지 확인

---

## 문제 해결

### Pod Pending

```bash
kubectl describe pod -n devops <pod-name>

# PVC 확인
kubectl get pvc -n devops
```

### Web UI 접속 실패

```bash
# Service 확인
kubectl get svc -n devops

# Ingress 확인
kubectl get ingress -n devops

# Port-forward 재시도
kubectl port-forward svc/gitlab-webservice-default -n devops 8080:8080
```

### Git Push 실패

```bash
# SSH Key 확인
ssh -T git@gitlab.kosa.local

# GitLab SSH Port 확인
kubectl get svc -n devops | grep ssh
```

---

## 참고 링크

1. **GitLab 공식 문서**: https://docs.gitlab.com/
2. **Helm Chart**: https://docs.gitlab.com/charts/

---

## 다음 단계

1. Harbor 설치 → 05-harbor-install.md
2. GitLab ↔ ArgoCD 연동 → 04-gitlab-argocd-workflow.md