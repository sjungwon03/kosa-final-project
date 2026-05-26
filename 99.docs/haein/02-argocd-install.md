# ArgoCD 설치 가이드 (테스트 노드)

작성자: haein

---

## 테스트 환경

**노드**: 192.168.34.2
**Namespace**: devops

---

## Step 1: Namespace 확인

```bash
ssh kosa@192.168.34.2

kubectl get namespace devops
```

---

## Step 2: ArgoCD 설치 YAML 생성

### 2-1. YAML 파일 생성

```bash
mkdir -p ~/k8s-yamls
cd ~/k8s-yamls

cat > argocd-install.yaml <<EOF
# ArgoCD Namespace (already created)
# kubectl create namespace devops

# ArgoCD Installation
# Apply from official repo
EOF
```

### 2-2. ArgoCD 설치

```bash
kubectl apply -n devops -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 설치 확인
kubectl get pods -n devops

# 모든 Pod Running 대기
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n devops --timeout=300s
```

---

## Step 3: ArgoCD Ingress YAML 생성

### 3-1. Ingress YAML

```bash
cat > argocd-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: devops
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "https"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.192.168.34.2.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
EOF

kubectl apply -f argocd-ingress.yaml
```

---

## Step 4: 초기 비밀번호 확인

```bash
kubectl -n devops get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**비밀번호 저장!**

---

## Step 5: Web UI 접속

### 5-1. Browser 접속

```
https://argocd.192.168.34.2.nip.io

Username: admin
Password: <Step 4에서 확인한 비밀번호>
```

### 5-2. Port-forward (Ingress 없을 때)

```bash
kubectl port-forward svc/argocd-server -n devops 8080:443 --address 192.168.34.2 &

# 접속: https://192.168.34.2:8080
```

---

## Step 6: CLI 설치

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd

argocd version
```

---

## Step 7: Application YAML 생성

### 7-1. Test Application YAML

```bash
cat > test-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: devops
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: devops
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

kubectl apply -f test-app.yaml
```

### 7-2. Sync

```bash
argocd app sync guestbook

# Web UI에서: Applications → guestbook → Sync
```

---

## Step 8: 확인

```bash
kubectl get pods -n devops -l app=guestbook

# Web UI: https://argocd.192.168.34.2.nip.io
# Applications → guestbook → Healthy 상태
```

---

## 참고 링크

1. **ArgoCD 공식 문서**: https://argo-cd.readthedocs.io/
2. **Getting Started**: https://argo-cd.readthedocs.io/en/stable/getting_started/

---

## 다음 단계

1. GitLab 설치 → 03-gitlab-install.md
2. Harbor 설치 → 05-harbor-install.md