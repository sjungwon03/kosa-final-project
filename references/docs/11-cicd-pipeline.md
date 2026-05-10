# CI/CD Pipeline (GitLab CI)

## 1. 개요

GitLab CI/CD를 사용하여 백엔드 서비스를 자동으로 빌드, 테스트, 배포합니다.

## 2. 파이프라인 구성

```
Build → Test → Deploy
  ↓       ↓       ↓
 Docker  pytest  Kubernetes
 Image   Tests   Rolling Update
```

## 3. GitLab 설정

### 3.1 GitLab Server
- **URL**: http://gitlab.kosa.local
- **Admin**: root / GitLabRootPassword123
- **Port**: 80 (HTTP), 443 (HTTPS), 22 (SSH)

### 3.2 GitLab Runner
- **Executor**: Kubernetes
- **Replicas**: 2
- **Namespace**: gitlab

## 4. Harbor Registry

### 4.1 Harbor Server
- **URL**: http://harbor.kosa.local
- **Admin**: admin / HarborAdmin123
- **Project**: kosa

### 4.2 이미지 저장
```
harbor.kosa.local/kosa/api-gateway:latest
harbor.kosa.local/kosa/employee-service:latest
harbor.kosa.local/kosa/welfare-service:latest
```

## 5. CI/CD 파이프라인

### 5.1 Build Stage
```yaml
build_api_gateway:
  stage: build
  script:
    - docker build -t harbor.kosa.local/kosa/api-gateway:$CI_COMMIT_SHA .
    - docker push harbor.kosa.local/kosa/api-gateway:$CI_COMMIT_SHA
    - docker push harbor.kosa.local/kosa/api-gateway:latest
```

### 5.2 Test Stage
```yaml
test_backend:
  stage: test
  script:
    - poetry install
    - poetry run pytest
```

### 5.3 Deploy Stage

#### 온프레미스 배포
```yaml
deploy_onprem:
  stage: deploy
  script:
    - kubectl set image deployment/api-gateway api-gateway=harbor.kosa.local/kosa/api-gateway:$CI_COMMIT_SHA
    - kubectl rollout status deployment/api-gateway
  environment: onprem
  when: manual
```

#### AWS 배포
```yaml
deploy_aws:
  stage: deploy
  script:
    - kubectl set image deployment/api-gateway api-gateway=harbor.kosa.local/kosa/api-gateway:$CI_COMMIT_SHA --context=aws
  environment: aws
  when: manual
```

## 6. GitLab Variables

| Variable              | 설명                          |
|-----------------------|-------------------------------|
| HARBOR_USER           | Harbor username               |
| HARBOR_PASSWORD       | Harbor password               |
| K8S_ONPREM_API_SERVER | 온프레미스 K8s API Server     |
| K8S_ONPREM_TOKEN      | 온프레미스 K8s Service Token  |
| K8S_AWS_API_SERVER    | AWS EKS API Server            |
| K8S_AWS_TOKEN         | AWS EKS Service Token         |

## 7. 배포 환경

### 7.1 온프레미스 환경
- **URL**: http://api.kosa.local
- **Context**: onprem
- **Namespace**: kosa

### 7.2 AWS 환경
- **URL**: http://api.kosa.com
- **Context**: aws
- **Namespace**: kosa

## 8. 롤백

```yaml
rollback_onprem:
  stage: deploy
  script:
    - kubectl rollout undo deployment/api-gateway
  when: manual
```

## 9. GitLab Runner 설정

### 9.1 Kubernetes Runner 등록
```bash
kubectl exec -it deployment/gitlab-runner -n gitlab -- \
  gitlab-runner register \
  --non-interactive \
  --url http://gitlab.gitlab.svc.cluster.local \
  --token $RUNNER_TOKEN \
  --executor kubernetes \
  --description "k8s-runner"
```

### 9.2 Runner Tags
- `k8s-runner`: Kubernetes runner

## 10. Harbor Registry Secret

### 10.1 Secret 생성
```bash
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.kosa.local \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  --namespace=kosa
```

## 11. 이미지 Pull

### 11.1 Deployment 설정
```yaml
spec:
  containers:
  - name: api-gateway
    image: harbor.kosa.local/kosa/api-gateway:latest
  imagePullSecrets:
  - name: harbor-registry-secret
```

## 12. CI/CD Flow

```
1. Git Push → GitLab
   ↓
2. GitLab Runner 트리거
   ↓
3. Build Stage
   - Docker Image Build
   - Harbor에 Push
   ↓
4. Test Stage
   - pytest 실행
   ↓
5. Deploy Stage (Manual)
   - 온프레미스 Deploy
   - 또는 AWS Deploy
   ↓
6. Kubernetes Rolling Update
   ↓
7. Service Health Check
```

## 13. 모니터링

### 13.1 GitLab Pipeline Status
- GitLab UI → CI/CD → Pipelines

### 13.2 Kubernetes Rollout Status
```bash
kubectl rollout status deployment/api-gateway -n kosa
kubectl get pods -n kosa
```