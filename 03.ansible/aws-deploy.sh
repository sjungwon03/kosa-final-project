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
    EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
    KEY_NAME=$(terraform output -raw ssh_key_name)
    NLB_DNS=$(terraform output -raw nlb_dns_name)
    
VPN_ENABLED=false
VPN_CONN_ID=""
TUNNEL1_ADDR=""
TUNNEL2_ADDR=""
if terraform output -json customer_gateway_id 2>/dev/null | grep -qv null; then
    CGW_ID=$(terraform output -raw customer_gateway_id 2>/dev/null)
    if [ -n "$CGW_ID" ] && [ "$CGW_ID" != "null" ]; then
        VPN_ENABLED=true
        VPN_CONN_ID=$(terraform output -raw vpn_connection_id 2>/dev/null)
        TUNNEL1_ADDR=$(terraform output -raw vpn_tunnel1_address 2>/dev/null)
        TUNNEL2_ADDR=$(terraform output -raw vpn_tunnel2_address 2>/dev/null)
    fi
fi
    
    cd "$WORKSPACE_DIR"
else
    echo "Error: Terraform state not found"
    echo "Run: cd ${PROJECT_ROOT}/02.terraform && ./aws-deploy.sh"
    exit 1
fi

echo ""
echo "Updating Ansible inventory..."
INVENTORY_FILE="inventories/aws/group_vars/all.yml"

AWS_PROFILE=$(grep -E "^aws_profile" ${TERRAFORM_DIR}/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' | head -1 || echo "kosa")

# Get HAProxy public IPs from terraform output
cd "$TERRAFORM_DIR"
if command -v jq &> /dev/null; then
    HAProxy_IP_1=$(terraform output -json ec2_public_ips | jq -r '.[0]')
    HAProxy_IP_2=$(terraform output -json ec2_public_ips | jq -r '.[1]')
else
    # Fallback without jq
    HAProxy_IP_1=$(terraform output ec2_public_ips | sed -n '2p' | tr -d '"')
    HAProxy_IP_2=$(terraform output ec2_public_ips | sed -n '3p' | tr -d '"')
fi
EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
KEY_NAME=$(terraform output -raw ssh_key_name)
NLB_DNS=$(terraform output -raw nlb_dns_name)
cd "$WORKSPACE_DIR"

if [ -z "$HAProxy_IP_1" ] || [ -z "$HAProxy_IP_2" ]; then
    echo "Error: Could not get HAProxy IPs from terraform output"
    echo "Run: cd ${TERRAFORM_DIR} && terraform output ec2_public_ips"
    exit 1
fi

cat > "$INVENTORY_FILE" << EOF
---
vault_aws_haproxy_1_ip: "${HAProxy_IP_1}"
vault_aws_haproxy_2_ip: "${HAProxy_IP_2}"
vault_haproxy_stats_pass: "$(openssl rand -base64 12)"
vault_ssh_key_path: "../../${KEY_NAME}.pem"

vault_onprem_cidr: "172.16.0.0/12"

vault_eks_ingress_ip: "WILL_BE_SET_AFTER_EKS_DEPLOY"
vault_prometheus_url: "http://172.16.30.50:9090"
EOF

echo ""
echo "HAProxy Public IPs: ${HAProxy_IP_1} ${HAProxy_IP_2}"

if [ "$VPN_ENABLED" = true ]; then
    echo ""
    echo "AWS Site-to-Site VPN Information:"
    echo "  VPN Connection ID: ${VPN_CONN_ID}"
    echo "  Tunnel 1 Address: ${TUNNEL1_ADDR}"
    echo "  Tunnel 2 Address: ${TUNNEL2_ADDR}"
    echo ""
    echo "pfSense IPsec Configuration (reference):"
    echo "  Phase 1 Remote Gateway: ${TUNNEL1_ADDR}"
    echo "  Phase 2 Local Network: 172.16.0.0/12"
    echo "  Phase 2 Remote Network: 10.20.0.0/16"
fi

echo ""
echo "[1/1] Deploying HAProxy..."
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml

echo ""
echo "========================================"
echo "  Ansible deployment completed!"
echo "========================================"
echo ""
echo "Next steps:"
echo ""
if [ "$VPN_ENABLED" = true ]; then
    echo "1. pfSense IPsec VPN 구성:"
    echo "   - AWS Tunnel 1: ${TUNNEL1_ADDR}"
    echo "   - Phase 1: IKEv1, AES-128, SHA1, DH Group 2"
    echo "   - Phase 2: 172.16.0.0/12 <-> 10.20.0.0/16"
    echo ""
fi
echo "2. EKS 배포:"
echo "   aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ap-northeast-2"
echo "   envsubst < ../../02.terraform/modules/aws/karpenter/templates/karpenter-provisioner.yaml.tpl | kubectl apply -f -"
echo ""
echo "3. EKS Ingress IP 확인 후 vault_eks_ingress_ip 설정"
echo ""
echo "4. HAProxy 재배포:"
echo "   ./aws-deploy.sh"
echo ""
echo "5. SSH 접속:"
echo "   ssh -i ../../${KEY_NAME}.pem ec2-user@$(echo "$EC2_PUBLIC_IPS" | sed -n '1p')"
echo ""
echo "6. NLB 확인:"
echo "   curl -I http://${NLB_DNS}/healthz"