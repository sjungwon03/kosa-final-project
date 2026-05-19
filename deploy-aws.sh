#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/02.terraform/env/aws"
ANSIBLE_DIR="${SCRIPT_DIR}/03.ansible/workspace"

echo "========================================"
echo "  AWS Infrastructure Deployment"
echo "========================================"

cd "$TERRAFORM_DIR"

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and fill in the values"
    exit 1
fi

echo "[1/3] Initializing Terraform..."
terraform init

echo "[2/3] Planning infrastructure..."
terraform plan -out=tfplan

echo "[3/3] Applying infrastructure..."
terraform apply tfplan

echo ""
echo "========================================"
echo "  Infrastructure deployed successfully!"
echo "========================================"

KEY_NAME=$(terraform output -raw ssh_key_name)
KEY_SRC="${SCRIPT_DIR}/02.terraform/modules/aws/keypair/${KEY_NAME}.pem"
KEY_DEST="${SCRIPT_DIR}/${KEY_NAME}.pem"

echo ""
echo "Copying SSH key to project root..."
cp "$KEY_SRC" "$KEY_DEST"
chmod 400 "$KEY_DEST"

echo ""
echo "Fetching instance IPs..."
EC2_IPS=$(terraform output -raw ec2_public_ips | tr ',' '\n')
VPN_IP=$(terraform output -raw vpn_instance_public_ip)

echo ""
echo "HAProxy Instance IPs:"
echo "$EC2_IPS"
echo ""
echo "VPN Instance IP: $VPN_IP"

echo ""
echo "Updating Ansible inventory..."
INVENTORY_FILE="${ANSIBLE_DIR}/inventories/aws/group_vars/vault.yml"

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

EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
EKS_ENDPOINT=$(terraform output -raw eks_cluster_endpoint)

echo ""
echo "EKS Cluster: ${EKS_CLUSTER}"
echo "EKS Endpoint: ${EKS_ENDPOINT}"

echo ""
echo "========================================"
echo "  SSH Key: ${KEY_DEST}"
echo "========================================"
echo ""
echo "Next steps:"
echo ""
echo "1. 온프렘 서버에서 WireGuard 키 생성:"
echo "   wg genkey | tee private.key | wg pubkey > public.key"
echo ""
echo "2. Ansible로 VPN 서버 배포:"
echo "   cd ${ANSIBLE_DIR}"
echo "   ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_vpn"
echo ""
echo "3. VPN 서버 public key 확인:"
echo "   ssh -i ${KEY_DEST} ec2-user@${VPN_IP} 'cat /etc/wireguard/public.key'"
echo ""
echo "4. VPN public key를 vault.yml의 vault_vpn_server_public_key에 설정"
echo "   온프렘 public key를 vault.yml의 vault_onprem_peer_public_key에 설정"
echo ""
echo "5. EKS kubeconfig 설정:"
echo "   aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ap-northeast-2"
echo ""
echo "6. Karpenter & 앱 배포 (EKS):"
echo "   CLUSTER_NAME=${EKS_CLUSTER}"
echo "   IMAGE_REGISTRY=<your-registry>"
echo "   envsubst < 02.terraform/modules/aws/karpenter/templates/karpenter-provisioner.yaml.tpl | kubectl apply -f -"
echo ""
echo "7. EKS Ingress LB IP 확인 후 vault_eks_ingress_ip 설정"
echo ""
echo "8. HAProxy 배포:"
echo "   ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_haproxy"
echo ""
echo "9. 온프렘 WireGuard 클라이언트 설정:"
echo "   참고: ${ANSIBLE_DIR}/onprem-wireguard-client.conf.example"
echo ""
echo "10. SSH 연결:"
echo "   ssh -i ${KEY_DEST} ec2-user@$(echo "$EC2_IPS" | sed -n '1p')"