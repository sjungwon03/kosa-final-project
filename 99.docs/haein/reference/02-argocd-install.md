# ArgoCD 설치 가이드 (초보자용)

작성자: haein

---

## ArgoCD가 무엇인가요?

ArgoCD는 GitOps 도구입니다.

**GitOps란?**
- Git repository에 YAML 파일을 push
- ArgoCD가 자동으로 Kubernetes에 배포
- Git이 변경되면 자동으로 클러스터 업데이트

**장점**:
- Git을 수정하면 자동 배포 (CLI 명령어 불필요)
- Web UI로 배포 상태 확인
- 여러 클러스터 관리 가능

---

## Step 1: Namespace 생성 (kosa21)

Kubernetes에서 namespace는 리소스를 그룹화합니다.

```bash
# kosa21 Master node에서 실행
kubectl create namespace devops

# 확인
kubectl get namespace devops

# 출력:
# NAME     STATUS   AGE
# devops   Active   5s
```

---

## Step 2: ArgoCD 설치 (kosa21)

### 2-1. ArgoCD 설치

```bash
kubectl apply -n devops -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**설치 내용**:
- argocd-application-controller
- argocd-repo-server
- argocd-server (Web UI)
- argocd-dex (Authentication)

### 2-2. 설치 확인

```bash
kubectl get pods -n devops

# 출력 (5분 대기):
# NAME                                    READY   STATUS
# argocd-application-controller-0         1/1     Running
# argocd-dex-server-xxxx                  1/1     Running
# argocd-repo-server-xxxx                 1/1     Running
# argocd-server-xxxx                      1/1     Running
```

### 2-3. Pod Running 대기

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n devops --timeout=300s
```

---

## Step 3: CLI 설치

ArgoCD를 CLI로 관리할 수 있습니다.

### macOS

```bash
brew install argocd
```

### Ubuntu/Linux

```bash
# 다운로드
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# 실행 권한
chmod +x argocd-linux-amd64

# 설치
sudo mv argocd-linux-amd64 /usr/local/bin/argocd

# 확인
argocd version
```

---

## Step 4: 초기 비밀번호 확인

### 4-1. 비밀번호 조회

```bash
kubectl -n devops get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 출력 예시:
# xYz123AbC456
```

**이 비밀번호를 저장하세요!**

---

## Step 5: Web UI 접속

### 5-1. Port-forward 설정

```bash
kubectl port-forward svc/argocd-server -n devops 8080:443 &

# 백그라운드에서 실행 (&)
```

### 5-2. Web UI 접속

Browser에서:
```
https://localhost:8080
```

**로그인**:
- Username: `admin`
- Password: Step 4에서 확인한 비밀번호

### 5-3. 비밀번호 변경

1. Web UI 로그인
2. User Info → Update Password
3. 새 비밀번호 입력
4. Update

---

## Step 6: Repository 연결

### 6-1. Public Repository

```bash
# 예: GitHub public repo
argocd repo add https://github.com/argoproj/argocd-example-apps.git
```

### 6-2. Private Repository (Token)

**GitHub Token 생성**:
1. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Generate new token
3. Repository access: 선택
4. Permissions: Contents → Read
5. Generate token → Token 저장

**ArgoCD에 등록**:
```bash
argocd repo add https://github.com/your-org/your-repo.git \
  --username your-username \
  --password ghp_xxxxxxxxxxxx
```

### 6-3. Web UI에서 등록

1. Settings → Repositories
2. Connect Repo
3. Repository URL 입력
4. Username/Password (Private인 경우)
5. Connect

---

## Step 7: Application 배포 테스트

### 7-1. Application 생성 (CLI)

```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

### 7-2. Application 생성 (Web UI)

1. Applications → Create Application
2. Application Name: `guestbook`
3. Project: `default`
4. Repository URL: `https://github.com/argoproj/argocd-example-apps.git`
5. Path: `guestbook`
6. Destination:
   - Server: `https://kubernetes.default.svc`
   - Namespace: `default`
7. Create

### 7-3. Sync (배포)

```bash
# CLI
argocd app sync guestbook

# Web UI
# Applications → guestbook → Sync
```

### 7-4. 확인

```bash
kubectl get pods -l app=guestbook

# 출력:
# NAME           READY   STATUS
# guestbook-xxx  1/1     Running
```

---

## Step 8: 자동 동기화 설정

Git push 시 자동으로 배포되게 설정합니다.

### YAML 파일 수정

```yaml
syncPolicy:
  automated:
    prune: true      # Git에서 삭제된 리소스 자동 삭제
    selfHeal: true   # 클러스터 변경 시 Git로 복구
```

### Web UI 설정

1. Applications → guestbook → Edit
2. Sync Options → Automated
3. Prune Resources: ☑
4. Self Heal: ☑
5. Save

---

## 자주 사용하는 명령어

```bash
# Application 목록
argocd app list

# Application 상태
argocd app get guestbook

# Sync
argocd app sync guestbook

# Refresh (Git 상태 확인)
argocd app refresh guestbook

# Delete
argocd app delete guestbook
```

---

## 문제 해결

### Application OutOfSync

Git과 클러스터 상태가 다릅니다.

```bash
# 상태 확인
argocd app get guestbook

# Sync
argocd app sync guestbook

# 강제 Sync
argocd app sync guestbook --force
```

### Repository 연결 실패

```bash
# Repository 상태 확인
argocd repo list

# Credential 재설정
argocd repo add https://github.com/xxx.git --username xxx --password xxx
```

### Pod Pending

```bash
# ArgoCD Pod 로그
kubectl logs -n devops deployment/argocd-application-controller

# 리소스 확인
kubectl describe pod -n devops <pod-name>
```

---

## 참고 링크

1. **ArgoCD 공식 문서**: https://argo-cd.readthedocs.io/
2. **Getting Started**: https://argo-cd.readthedocs.io/en/stable/getting_started/

---

## 다음 단계

1. GitLab 설치 → 03-gitlab-install.md
2. GitLab ↔ ArgoCD 연동 → 04-gitlab-argocd-workflow.md