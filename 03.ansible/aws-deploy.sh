#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="${PROJECT_ROOT}/02.terraform/env/aws"
WORKSPACE_DIR="${SCRIPT_DIR}/workspace"

echo "========================================"
echo "  Ansible Deployment (AWS)"
echo "========================================"

cd "$WORKSPACE_DIR"

if [ -f "${TERRAFORM_DIR}/terraform.tfstate" ]; then
    cd "$TERRAFORM_DIR"
    EC2_IPS=$(terraform output -raw ec2_public_ips | tr ',' '\n')
    VPN_IP=$(terraform output -raw vpn_instance_public_ip)
    EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
    KEY_NAME=$(terraform output -raw ssh_key_name)
    cd "$WORKSPACE_DIR"
else
    echo "Error: Terraform state not found"
    echo "Run: cd ${PROJECT_ROOT}/02.terraform && ./aws-deploy.sh"
    exit 1
fi

echo ""
echo "Updating Ansible inventory..."
INVENTORY_FILE="inventories/aws/group_vars/vault.yml"

cat > "$INVENTORY_FILE" << EOF
---
vault_aws_haproxy_1_ip: "$(echo "$EC2_IPS" | sed -n '1p')"
vault_aws_haproxy_2_ip: "$(echo "$EC2_IPS" | sed -n '2p')"
vault_aws_vpn_ip: "${VPN_IP}"
vault_haproxy_stats_pass: "$(openssl rand -base64 12)"
vault_ssh_key_path: "../../${KEY_NAME}.pem"

vault_onprem_peer_public_key: "REPLACE_WITH_ONPREM_WIREGUARD_PUBLIC_KEY"
vault_onprem_peer_allowed_ips: "172.16.0.0/16"
vault_onprem_peer_endpoint: ""

vault_wireguard_client_ip: "10.100.0.2/24"
vault_vpn_server_public_key: "WILL_BE_SET_AFTER_VPN_DEPLOY"

vault_eks_ingress_ip: "WILL_BE_SET_AFTER_EKS_DEPLOY"
vault_prometheus_url: "http://172.16.30.50:9090"
EOF

echo ""
echo "HAProxy IPs: $(echo "$EC2_IPS" | tr '\n' ' ')"
echo "VPN IP: ${VPN_IP}"

echo ""
echo "[1/3] Deploying VPN Server..."
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_vpn

echo ""
echo "[2/3] Fetching VPN public key..."
VPN_PUBKEY=$(ssh -i "${PROJECT_ROOT}/${KEY_NAME}.pem" ec2-user@${VPN_IP} 'cat /etc/wireguard/public.key' 2>/dev/null || echo "")

if [ -n "$VPN_PUBKEY" ]; then
    echo "VPN Public Key: ${VPN_PUBKEY}"
    
    sed -i.bak "s/WILL_BE_SET_AFTER_VPN_DEPLOY/${VPN_PUBKEY}/" "$INVENTORY_FILE"
    echo "vault.yml updated with VPN public key"
fi

echo ""
echo "[3/3] Deploying HAProxy..."
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_haproxy

echo ""
echo "========================================"
echo "  Ansible deployment completed!"
echo "========================================"
echo ""
echo "Next steps:"
echo ""
echo "1. 온프렘 WireGuard 키 생성 및 vault.yml 업데이트:"
echo "   vault_onprem_peer_public_key: <ONPREM_PUBKEY>"
echo ""
echo "2. EKS 배포:"
echo "   aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ap-northeast-2"
echo "   envsubst < ../../02.terraform/modules/aws/karpenter/templates/karpenter-provisioner.yaml.tpl | kubectl apply -f -"
echo ""
echo "3. EKS Ingress IP 확인 후 vault_eks_ingress_ip 설정"
echo ""
echo "4. HAProxy 재배포:"
echo "   ./aws-deploy.sh"
echo ""
echo "5. 온프렘 WireGuard 클라이언트 설정:"
echo "   참고: onprem-wireguard-client.conf.example"