#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_ENV_DIR="${SCRIPT_DIR}/env/aws"

echo "========================================"
echo "  AWS Terraform Deployment"
echo "========================================"

cd "$TERRAFORM_ENV_DIR"

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and fill in the values"
    exit 1
fi

AWS_PROFILE=$(grep -E "^aws_profile" terraform.tfvars | cut -d'=' -f2 | tr -d ' "' | head -1)
if [ -z "$AWS_PROFILE" ]; then
    AWS_PROFILE="kosa"
fi

echo "AWS Profile: ${AWS_PROFILE}"

if ! aws sts get-caller-identity --profile "$AWS_PROFILE" > /dev/null 2>&1; then
    echo "Error: AWS profile '${AWS_PROFILE}' not configured"
    echo "Run: aws configure --profile ${AWS_PROFILE}"
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
KEY_SRC="${SCRIPT_DIR}/modules/aws/keypair/${KEY_NAME}.pem"
KEY_DEST="${PROJECT_ROOT}/${KEY_NAME}.pem"

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
echo "1. Ansible 배포:"
echo "   cd ${PROJECT_ROOT}/03.ansible"
echo "   ./aws-deploy.sh"
echo ""
echo "2. EKS kubeconfig 설정:"
echo "   aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ap-northeast-2"
echo ""
echo "3. SSH 연결:"
echo "   ssh -i ${KEY_DEST} ec2-user@$(echo "$EC2_IPS" | sed -n '1p')"