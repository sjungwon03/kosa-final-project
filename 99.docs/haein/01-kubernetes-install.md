# Kubernetes 테스트 클러스터 설치 가이드

작성자: haein

---

## 테스트 환경

**테스트 노드**: 192.168.34.2 (단일 노드)

**설치 서비스**:
- Kubernetes (kubeadm)
- ArgoCD (GitOps)
- GitLab (Git + CI/CD)
- Harbor (Container Registry)

---

## Step 1: VM 접속

```bash
ssh kosa@192.168.34.2
Password: kosa1004
```

---

## Step 2: 시스템 준비

### 2-1. 시스템 업데이트

```bash
sudo apt update && sudo apt upgrade -y
```

### 2-2. 필수 패키지 설치

```bash
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg
```

### 2-3. Swap 비활성화

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 확인
free -h
```

### 2-4. 커널 모듈 설정

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

### 2-5. 네트워크 설정

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

---

## Step 3: Containerd 설치

### 3-1. Docker Repository 추가

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
```

### 3-2. containerd 설치

```bash
sudo apt install -y containerd.io

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

---

## Step 4: Kubernetes 설치

### 4-1. Kubernetes Repository 추가

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
```

### 4-2. 패키지 설치

```bash
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
```

---

## Step 5: Kubernetes 클러스터 초기화

### 5-1. 클러스터 생성

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

### 5-2. kubectl 설정

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc
```

### 5-3. Master 노드에 Pod 배포 허용

단일 노드이므로 Master에도 Pod를 배포합니다.

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

---

## Step 6: 네트워크 플러그인 설치

### 6-1. Flannel 설치

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

---

## Step 7: Namespace 생성

```bash
kubectl create namespace devops

# YAML로 생성
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: devops
EOF
```

---

## Step 8: 클러스터 확인

```bash
kubectl get nodes

# 출력:
# NAME         STATUS   ROLES           AGE   VERSION
# 192.168.34.2 Ready    control-plane   5m    v1.31.0

kubectl get pods -A
```

---

## 참고 문서

https://github.com/masungil70/docker-kubernetes/tree/main/chapter5

---

## 다음 단계

1. ArgoCD 설치 → 02-argocd-install.md
2. GitLab 설치 → 03-gitlab-install.md
3. Harbor 설치 → 05-harbor-install.md