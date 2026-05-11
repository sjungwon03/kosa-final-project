# GitLab & Harbor 구성

## 1. GitLab

### 1.1 GitLab CE (Community Edition)
- **Image**: gitlab/gitlab-ce:latest
- **Namespace**: gitlab
- **Port**: 80 (HTTP), 443 (HTTPS), 22 (SSH)

### 1.2 Storage
- **Config**: /etc/gitlab (1Gi PVC)
- **Logs**: /var/log/gitlab (1Gi PVC)
- **Data**: /var/opt/gitlab (20Gi PVC)

### 1.3 Configuration
```yaml
GITLAB_OMNIBUS_CONFIG: |
  external_url 'http://gitlab.kosa.local'
  gitlab_rails['gitlab_shell_ssh_port'] = 22
  registry['enable'] = false
```

### 1.4 Resource Requirements
- **CPU**: 2-4 cores
- **Memory**: 4-8 GB

## 2. GitLab Runner

### 2.1 Runner Configuration
- **Executor**: Kubernetes
- **Replicas**: 2
- **Namespace**: gitlab

### 2.2 Runner Registration
```bash
gitlab-runner register \
  --non-interactive \
  --url http://gitlab.gitlab.svc.cluster.local \
  --token ${RUNNER_TOKEN} \
  --executor kubernetes \
  --description "k8s-runner"
```

### 2.3 Runner Environment
- **Image**: gitlab/gitlab-runner:latest
- **Pods**: Dynamic pods created per job

## 3. Harbor Registry

### 3.1 Harbor Components
- **Harbor Core**: Main service (goharbor/harbor-core:v2.8.0)
- **Harbor Registry**: Docker registry (goharbor/registry-photon:v2.8.0)
- **Harbor Portal**: Web UI (goharbor/harbor-portal:v2.8.0)
- **Harbor JobService**: Job execution (goharbor/harbor-jobservice:v2.8.0)
- **Harbor DB**: PostgreSQL (goharbor/harbor-db:v2.8.0)

### 3.2 Storage
- **Registry Data**: 50Gi PVC
- **Database Data**: 5Gi PVC

### 3.3 Configuration
```yaml
harbor.yml: |
  hostname: harbor.kosa.local
  http_port: 80
  harbor_admin_password: HarborAdmin123
```

### 3.4 Image Registry
```
harbor.kosa.local/kosa/api-gateway:latest
harbor.kosa.local/kosa/employee-service:latest
harbor.kosa.local/kosa/welfare-service:latest
```

## 4. Deployment

### 4.1 GitLab 배포
```bash
kubectl apply -f kubernetes/gitlab/gitlab.yaml
```

### 4.2 Harbor 배포
```bash
kubectl apply -f kubernetes/harbor/harbor.yaml
```

### 4.3 상태 확인
```bash
kubectl get pods -n gitlab
kubectl get pods -n harbor
```

## 5. GitLab 초기 설정

### 5.1 Root 계정
- **Username**: root
- **Password**: GitLabRootPassword123

### 5.2 Project 생성
1. GitLab UI 접속 (http://gitlab.kosa.local)
2. New Project → Create blank project
3. Project name: kosa-backend

### 5.3 Runner Token 등록
1. GitLab → Settings → CI/CD → Runners
2. New Project Runner → Token 복사
3. Kubernetes Secret에 등록

## 6. Harbor 초기 설정

### 6.1 Admin 계정
- **Username**: admin
- **Password**: HarborAdmin123

### 6.2 Project 생성
1. Harbor UI 접속 (http://harbor.kosa.local)
2. New Project → kosa project 생성

### 6.3 Repository 생성
- api-gateway
- employee-service
- welfare-service

## 7. Kubernetes Secret

### 7.1 Harbor Registry Secret
```bash
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=harbor.kosa.local \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  --namespace=kosa
```

### 7.2 Secret 확인
```bash
kubectl get secret harbor-registry-secret -n kosa
```

## 8. 이미지 Push/Pull

### 8.1 Docker Login
```bash
docker login harbor.kosa.local -u admin -p HarborAdmin123
```

### 8.2 Image Build & Push
```bash
docker build -t harbor.kosa.local/kosa/api-gateway:latest ./backend
docker push harbor.kosa.local/kosa/api-gateway:latest
```

### 8.3 Image Pull (Kubernetes)
```yaml
spec:
  containers:
  - name: api-gateway
    image: harbor.kosa.local/kosa/api-gateway:latest
  imagePullSecrets:
  - name: harbor-registry-secret
```

## 9. Service Access

### 9.1 GitLab Service
- **Internal**: http://gitlab.gitlab.svc.cluster.local
- **External**: http://gitlab.kosa.local (LoadBalancer)

### 9.2 Harbor Service
- **Internal**: http://harbor.harbor.svc.cluster.local
- **External**: http://harbor.kosa.local (LoadBalancer)

## 10. Monitoring

### 10.1 GitLab Logs
```bash
kubectl logs -f deployment/gitlab -n gitlab
```

### 10.2 Harbor Logs
```bash
kubectl logs -f deployment/harbor-core -n harbor
kubectl logs -f deployment/harbor-registry -n harbor
```

## 11. Troubleshooting

### 11.1 GitLab 시작 실패
```bash
kubectl describe pod gitlab-xxx -n gitlab
kubectl logs gitlab-xxx -n gitlab --previous
```

### 11.2 Harbor Registry Push 실패
```bash
docker login harbor.kosa.local
kubectl get pods -n harbor | grep registry
kubectl logs deployment/harbor-registry -n harbor
```

### 11.3 ImagePullBackOff
```bash
kubectl describe pod api-gateway-xxx -n kosa
kubectl get secret harbor-registry-secret -n kosa
```