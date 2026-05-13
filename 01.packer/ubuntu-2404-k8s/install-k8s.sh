#!/bin/bash
set -e

K8S_VERSION="1.32"

# swap 비활성화
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# 커널 모듈
sudo modprobe overlay
sudo modprobe br_netfilter
printf 'overlay\nbr_netfilter\n' | sudo tee /etc/modules-load.d/k8s.conf

# sysctl
printf 'net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1\n' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system

# containerd
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl enable containerd

# kubeadm / kubelet / kubectl
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl disable kubelet

sudo apt-get clean

# 쉘 구문 자동완성 플러그인
sudo apt-get install -y bash-completion

echo "source <(kubectl completion bash)" >> /home/kosa/.bashrc
echo "source <(kubeadm completion bash)" >> /home/kosa/.bashrc

# 별칭
echo 'alias k=kubectl' >> /home/kosa/.bashrc
echo 'complete -o default -F __start_kubectl k' >> /home/kosa/.bashrc

