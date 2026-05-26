# Harbor Container Registry 설치 가이드 (초보자용)

작성자: haein

---

## Harbor가 무엇인가요?

Harbor는 Container Registry입니다.

**기능**:
- Docker 이미지 저장
- Helm Chart 저장
- Vulnerability Scanning (이미지 취약점 검사)
- RBAC (권한 관리)

---

## Step 1: Namespace 확인

```bash
kubectl get namespace devops

# 없으면 생성
kubectl create namespace devops
```

---

## Step 2: Helm Repository 추가

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update

# 확인
helm repo list
```

---

## Step 3: Harbor 설치

### 3-1. 설치

```bash
helm install harbor harbor/harbor \
  --namespace devops \
  --set expose.type=ingress \
  --set expose.ingress.hosts.core=harbor.kosa.local \
  --set externalURL=https://harbor.kosa.local \
  --set harborAdminPassword=Harbor12345 \
  --set persistence.enabled=true \
  --set trivy.enabled=true \
  --set chartmuseum.enabled=true \
  --timeout 600s
```

**설치 시간**: 5-10분

### 3-2. 설치 확인

```bash
kubectl get pods -n devops | grep harbor

# 출력:
# NAME                    READY   STATUS
# harbor-core-xxx         1/1     Running
# harbor-registry-xxx     1/1     Running
# harbor-portal-xxx       1/1     Running
# harbor-trivy-xxx        1/1     Running
```

---

## Step 4: Web UI 접속

### 4-1. Port-forward

```bash
kubectl port-forward svc/harbor -n devops 8080:80 &
```

### 4-2. Browser 접속

```
http://localhost:8080
```

### 4-3. 로그인

- Username: `admin`
- Password: `Harbor12345`

---

## Step 5: Project 생성

### 5-1. Web UI에서

1. Projects → New Project
2. Project Name: `devops`
3. Access Level: `Private`
4. Create

---

## Step 6: Docker Client 설정

### 6-1. 로그인

```bash
docker login harbor.kosa.local

Username: admin
Password: Harbor12345

# 출력:
# Login Succeeded
```

### 6-2. Insecure Registry (HTTP인 경우)

HTTPS가 아니면 Docker 설정이 필요합니다.

```bash
# /etc/docker/daemon.json 수정
sudo vim /etc/docker/daemon.json

{
  "insecure-registries": ["harbor.kosa.local"]
}

# Docker 재시작
sudo systemctl restart docker
```

---

## Step 7: 이미지 Push/Pull

### 7-1. 이미지 Tag

```bash
# 예: Ubuntu 이미지
docker pull ubuntu:22.04
docker tag ubuntu:22.04 harbor.kosa.local/devops/ubuntu:22.04
```

### 7-2. Push

```bash
docker push harbor.kosa.local/devops/ubuntu:22.04

# 출력:
# 22.04: digest: sha256:xxx size: xxx
```

### 7-3. Web UI 확인

1. Projects → devops → Images
2. ubuntu:22.04 확인

### 7-4. Pull

```bash
docker pull harbor.kosa.local/devops/ubuntu:22.04
```

---

## Step 8: Vulnerability Scanning

### 8-1. 이미지 Scan

1. Web UI → Projects → devops → Images
2. ubuntu:22.04 선택
3. Scan 버튼 클릭
4. Scan 결과 확인 (CVE 목록)

### 8-2. Severity 확인

- Critical: 즉시 수정 필요
- High: 수정 필요
- Medium: 확인 필요
- Low: 정보

---

## Step 9: Kubernetes Secret 생성

Kubernetes Pod에서 Harbor 이미지를 pull하기 위한 설정입니다.

### 9-1. Secret 생성

```bash
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.kosa.local \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --namespace devops

# 확인
kubectl get secret harbor-secret -n devops
```

### 9-2. Pod에서 사용

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: devops
spec:
  replicas: 1
  template:
    spec:
      imagePullSecrets:
      - name: harbor-secret
      containers:
      - name: my-app
        image: harbor.kosa.local/devops/my-app:latest
```

---

## Step 10: Robot Account (CI/CD용)

GitLab CI에서 Harbor 이미지 push용 계정입니다.

### 10-1. Robot Account 생성

1. Web UI → Projects → devops → Robot Accounts
2. Add Robot Account
3. Name: `gitlab-ci`
4. Permissions: Read/Write
5. Save → Token 복사

### 10-2. GitLab CI에서 사용

```yaml
# .gitlab-ci.yml
variables:
  HARBOR_URL: harbor.kosa.local
  HARBOR_USER: robot$gitlab-ci
  HARBOR_PASSWORD: <token>

build:
  script:
    - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD $HARBOR_URL
    - docker build -t $HARBOR_URL/devops/my-app:$CI_COMMIT_SHA .
    - docker push $HARBOR_URL/devops/my-app:$CI_COMMIT_SHA
```

---

## 문제 해결

### Push 실패

```bash
# 로그인 확인
docker login harbor.kosa.local

# Registry Pod 확인
kubectl logs -n devops deployment/harbor-registry
```

### Scan 실패

```bash
# Trivy Pod 로그
kubectl logs -n devops deployment/harbor-trivy

# PVC 확인
kubectl get pvc -n devops | grep trivy
```

### Kubernetes Image Pull 실패

```bash
# Secret 확인
kubectl describe secret harbor-secret -n devops

# Secret 재생성
kubectl delete secret harbor-secret -n devops
kubectl create secret docker-registry harbor-secret ...
```

---

## 참고 링크

1. **Harbor 공식 문서**: https://goharbor.io/docs
2. **Helm Chart**: https://github.com/goharbor/harbor-helm

---

## 다음 단계

1. GitLab ↔ ArgoCD 연동 → 04-gitlab-argocd-workflow.md