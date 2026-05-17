# Harbor 설치 가이드 (테스트 노드)

작성자: haein

---

## 테스트 환경

**노드**: 192.168.34.2
**Namespace**: devops

---

## Step 1: Helm Repository 추가

```bash
ssh kosa@192.168.34.2

helm repo add harbor https://helm.goharbor.io
helm repo update
```

---

## Step 2: Harbor values YAML 생성

### 2-1. values.yaml 파일

```bash
mkdir -p ~/k8s-yamls/harbor
cd ~/k8s-yamls/harbor

cat > values.yaml <<EOF
expose:
  type: ingress
  ingress:
    hosts:
      core: harbor.192.168.34.2.nip.io
    annotations:
      nginx.ingress.kubernetes.io/proxy-body-size: "0"

externalURL: https://harbor.192.168.34.2.nip.io

harborAdminPassword: "Harbor12345"

persistence:
  enabled: false

trivy:
  enabled: false

chartmuseum:
  enabled: true
EOF
```

---

## Step 3: Harbor 설치

```bash
helm install harbor harbor/harbor \
  --namespace devops \
  --values values.yaml \
  --timeout 600s

# 설치 확인
kubectl get pods -n devops | grep harbor

# 5-10분 대기
kubectl wait --for=condition=ready pod -l component=core -n devops --timeout=600s
```

---

## Step 4: Web UI 접속

```
https://harbor.192.168.34.2.nip.io

Username: admin
Password: Harbor12345
```

### Port-forward (Ingress 없을 때)

```bash
kubectl port-forward svc/harbor -n devops 8080:80 --address 192.168.34.2 &

# 접속: http://192.168.34.2:8080
```

---

## Step 5: Project 생성

1. Web UI → Projects → New Project
2. Project Name: `devops`
3. Access Level: Private
4. Create

---

## Step 6: Docker 로그인

### 6-1. 로그인

```bash
docker login harbor.192.168.34.2.nip.io

Username: admin
Password: Harbor12345
```

### 6-2. Insecure Registry 설정

HTTPS certificate 없으면 설정 필요:

```bash
sudo vim /etc/docker/daemon.json

{
  "insecure-registries": ["harbor.192.168.34.2.nip.io"]
}

sudo systemctl restart docker
```

---

## Step 7: 이미지 Push/Pull 테스트

### 7-1. 이미지 Tag

```bash
docker pull nginx:alpine
docker tag nginx:alpine harbor.192.168.34.2.nip.io/devops/nginx:alpine
```

### 7-2. Push

```bash
docker push harbor.192.168.34.2.nip.io/devops/nginx:alpine
```

### 7-3. Pull

```bash
docker pull harbor.192.168.34.2.nip.io/devops/nginx:alpine
```

---

## Step 8: Kubernetes Secret YAML 생성

Pod에서 Harbor 이미지 pull용 Secret:

```bash
cat > harbor-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret
  namespace: devops
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo -n '{"auths":{"harbor.192.168.34.2.nip.io":{"username":"admin","password":"Harbor12345"}}}' | base64 | tr -d '\n')
EOF

kubectl apply -f harbor-secret.yaml
```

---

## Step 9: Robot Account 생성

### 9-1. Web UI에서

1. Projects → devops → Robot Accounts
2. Add Robot Account
3. Name: `gitlab-ci`
4. Permissions: Read/Write
5. Save → Token 복사

---

## 참고 링크

1. **Harbor 공식 문서**: https://goharbor.io/docs
2. **Helm Chart**: https://github.com/goharbor/harbor-helm

---

## 다음 단계

1. GitLab ↔ ArgoCD 연동 → 04-gitlab-argocd-workflow.md