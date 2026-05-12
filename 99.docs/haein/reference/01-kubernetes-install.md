# Kubernetes 클러스터 설치 가이드 (초보자용)

작성자: haein

---

## 이 가이드를 따라하면 무엇을 만들 수 있나요?

Proxmox VM 4대로 Kubernetes 클러스터를 구성합니다.
- kosa21: Master node (클러스터 관리)
- kosa22, kosa23, kosa24: Worker node (앱 실행)

---

## 사전 준비

### 1. VM 생성

Proxmox에서 Ubuntu 24.04 VM 4대 생성:

| VM 이름 | CPU | Memory | Disk | IP          |
|---------|-----|--------|------|-------------|
| kosa21  | 4   | 8GB    | 50GB | 172.16.30.21|
| kosa22  | 4   | 8GB    | 50GB | 172.16.30.22|
| kosa23  | 4   | 8GB    | 50GB | 172.16.30.23|
| kosa24  | 4   | 8GB    | 50GB | 172.16.30.24|

**VM 생성 방법**:
1. Proxmox Web UI 접속 (https://192.168.40.21:8006)
2. Create VM 클릭
3. OS: Ubuntu 24.04 ISO 선택
4. CPU: 4 cores
5. Memory: 8192 MB
6. Disk: 50GB (rbd-storage)
7. Network: VLAN 30
8. Start 후 Ubuntu 설치

### 2. SSH 접속

```bash
# Terminal에서
ssh kosa@172.16.30.21
Password: kosa1004

# 각 VM에 접속하여 hostname 설정
sudo hostnamectl set-hostname kosa21  # kosa21에서
sudo hostnamectl set-hostname kosa22  # kosa22에서
sudo hostnamectl set-hostname kosa23  # kosa23에서
sudo hostnamectl set-hostname kosa24  # kosa24에서
```

---

## Step 1: 모든 VM 준비 (4대 모두)

**중요**: 모든 VM (kosa21, kosa22, kosa23, kosa24)에서 실행!

### 1-1. 시스템 업데이트

```bash
sudo apt update && sudo apt upgrade -y
```

### 1-2. 필수 패키지 설치

```bash
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg
```

### 1-3. Swap 비활성화

Kubernetes는 swap을 사용하지 않습니다.

```bash
# Swap 끄기
sudo swapoff -a

# 재부팅 후에도 swap 안 켜지게 설정
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 확인 (모든 swap이 0이어야 함)
free -h
```

### 1-4. 커널 모듈 설정

```bash
# 필요한 커널 모듈 로드
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 확인
lsmod | grep overlay
lsmod | grep br_netfilter
```

### 1-5. 네트워크 설정

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 적용
sudo sysctl --system

# 확인
sysctl net.bridge.bridge-nf-call-iptables
# 출력: net.bridge.bridge-nf-call-iptables = 1
```

---

## Step 2: Containerd 설치 (4대 모두)

Kubernetes는 Docker 대신 containerd를 사용합니다.

### 2-1. Docker Repository 추가

```bash
# GPG key 다운로드
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Repository 추가
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 업데이트
sudo apt update
```

### 2-2. containerd 설치

```bash
sudo apt install -y containerd.io
```

### 2-3. containerd 설정

```bash
# 설정 파일 생성
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# SystemdCgroup 활성화 (필수!)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# containerd 재시작
sudo systemctl restart containerd
sudo systemctl enable containerd

# 상태 확인
sudo systemctl status containerd
# Active: active (running)
```

---

## Step 3: Kubernetes 패키지 설치 (4대 모두)

### 3-1. Kubernetes Repository 추가

```bash
# GPG key 다운로드
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Repository 추가
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 업데이트
sudo apt update
```

### 3-2. 패키지 설치

```bash
sudo apt install -y kubeadm kubelet kubectl

# 버전 고정 (자동 업그레이드 방지)
sudo apt-mark hold kubeadm kubelet kubectl

# 버전 확인
kubeadm version
kubectl version --client
```

---

## Step 4: Master 노드 초기화 (kosa21만)

**중요**: kosa21에서만 실행!

### 4-1. 클러스터 초기화

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=172.16.30.21
```

**출력 예시**:
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.16.30.21:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### 4-2. join 명령어 저장

위 출력의 `kubeadm join` 명령어를 **복사해서 저장**하세요!
이 명령어로 worker node를 추가합니다.

### 4-3. kubectl 설정

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 4-4. kubectl 자동완성

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc
```

---

## Step 5: 네트워크 플러그인 설치 (kosa21만)

Pod가 서로 통신하려면 네트워크 플러그인이 필요합니다.

### 5-1. Flannel 설치

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### 5-2. 확인

```bash
kubectl get pods -n kube-flannel

# 출력:
# NAME                    READY   STATUS    AGE
# kube-flannel-ds-xxxx    1/1     Running   30s
```

---

## Step 6: Worker 노드 추가 (kosa22, kosa23, kosa24)

### 6-1. kosa22에서 실행

```bash
sudo kubeadm join 172.16.30.21:6443 --token <TOKEN> --discovery-token-ca-cert-hash <HASH>

# <TOKEN>과 <HASH>는 Step 4-2에서 저장한 값
```

### 6-2. kosa23에서 실행

```bash
sudo kubeadm join 172.16.30.21:6443 --token <TOKEN> --discovery-token-ca-cert-hash <HASH>
```

### 6-3. kosa24에서 실행

```bash
sudo kubeadm join 172.16.30.21:6443 --token <TOKEN> --discovery-token-ca-cert-hash <HASH>
```

### 토큰 재생성 (필요시)

토큰을 저장하지 않았거나 만료된 경우:

```bash
# kosa21에서 실행
kubeadm token create --print-join-command

# 출력된 명령어를 worker node에서 실행
```

---

## Step 7: 클러스터 확인 (kosa21)

### 7-1. 노드 상태 확인

```bash
kubectl get nodes

# 출력:
# NAME     STATUS   ROLES           AGE   VERSION
# kosa21   Ready    control-plane   10m   v1.31.0
# kosa22   Ready    <none>          5m    v1.31.0
# kosa23   Ready    <none>          5m    v1.31.0
# kosa24   Ready    <none>          5m    v1.31.0
```

**모든 노드가 Ready 상태**여야 합니다.

### 7-2. Pod 상태 확인

```bash
kubectl get pods -A

# 모든 Pod가 Running 상태
```

### 7-3. Component 상태 확인

```bash
kubectl get cs

# 출력:
# NAME                 STATUS    MESSAGE
# scheduler            Healthy   ok
# controller-manager   Healthy   ok
# etcd                 Healthy   ok
```

---

## 문제 해결

### 노드 NotReady

```bash
# 네트워크 플러그인 확인
kubectl get pods -n kube-flannel

# Flannel Pod Running 안 되면:
kubectl describe pod -n kube-flannel <pod-name>
```

### Worker Node Join 실패

```bash
# Master에서 토큰 확인
kubeadm token list

# 토큰 만료면 재생성
kubeadm token create --print-join-command
```

### Pod Pending

```bash
# Pod 상태 확인
kubectl describe pod <pod-name> -n <namespace>

# Events 확인
kubectl get events -A
```

---

## 참고 문서

https://github.com/masungil70/docker-kubernetes/tree/main/chapter5

이 repository의 내용을 따라 진행했습니다.

---

## 다음 단계

1. ArgoCD 설치 → 02-argocd-install.md
2. GitLab 설치 → 03-gitlab-install.md
3. Harbor 설치 → 05-harbor-install.md