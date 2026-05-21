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
rm -f "$KEY_DEST" 2>/dev/null || true
cp "$KEY_SRC" "$KEY_DEST"
chmod 400 "$KEY_DEST"

echo ""
echo "Fetching instance IPs..."
EC2_PRIVATE_IPS=$(terraform output ec2_private_ips | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
EC2_PUBLIC_IPS=""
if terraform output ec2_public_ips 2>/dev/null | grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
    EC2_PUBLIC_IPS=$(terraform output ec2_public_ips | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
fi

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

echo ""
echo "HAProxy Private IPs (SSM access):"
echo "$EC2_PRIVATE_IPS"

if [ -n "$EC2_PUBLIC_IPS" ]; then
    echo ""
    echo "HAProxy Public IPs (SSH access):"
    echo "$EC2_PUBLIC_IPS"
fi

if [ "$VPN_ENABLED" = true ]; then
    echo ""
    echo "AWS Site-to-Site VPN:"
    echo "  Connection ID: ${VPN_CONN_ID}"
    echo "  Tunnel 1: ${TUNNEL1_ADDR}"
    echo "  Tunnel 2: ${TUNNEL2_ADDR}"
    
    echo ""
    echo "Downloading VPN Configuration for pfSense..."
    terraform output -raw vpn_customer_gateway_configuration > "${PROJECT_ROOT}/vpn-configuration.xml"
    echo "  Saved to: ${PROJECT_ROOT}/vpn-configuration.xml"
    
    echo ""
    echo "pfSense IPsec Configuration Guide:"
    echo "  ${TERRAFORM_ENV_DIR}/PFSENSE_IPSEC_SETUP.md"
fi

EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
EKS_ENDPOINT=$(terraform output -raw eks_cluster_endpoint)
NLB_DNS=$(terraform output -raw nlb_dns_name)

echo ""
echo "EKS Cluster: ${EKS_CLUSTER}"
echo "EKS Endpoint: ${EKS_ENDPOINT}"
echo "NLB DNS: ${NLB_DNS}"

ROUTE53_NS=$(terraform output route53_name_servers | grep -oE 'ns-[0-9]+\.awsdns-[0-9]+\.[a-z]+\.[a-z]+' || echo "")
if [ -z "$ROUTE53_NS" ]; then
    ROUTE53_NS=$(terraform output route53_name_servers | grep -E 'ns-' | sed 's/.*"\([^"]*\)".*/\1/' | tr '\n' ' ')
fi
if [ -n "$ROUTE53_NS" ]; then
    echo ""
    echo "Route53 Name Servers (for NS delegation):"
    echo "$ROUTE53_NS"
fi

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
if [ "$VPN_ENABLED" = true ]; then
    echo "2. pfSense IPsec VPN 구성:"
    echo "   참고: ${TERRAFORM_ENV_DIR}/IPSEC_VPN_SETUP.md"
    echo "   AWS Tunnel 1: ${TUNNEL1_ADDR}"
    echo ""
fi
echo "3. EKS kubeconfig 설정:"
echo "   aws eks update-kubeconfig --name ${EKS_CLUSTER} --region ap-northeast-2"
echo ""
echo "4. SSM Session Manager 접속 (private EC2):"
echo "   AWS Console → Systems Manager → Session Manager"
INSTANCE_IDS=$(terraform output haproxy_instance_ids | grep -oE 'i-[a-z0-9]+' | tr '\n' ' ')
echo "   Instance IDs: ${INSTANCE_IDS}"
echo ""
echo "5. Route53 NS 위임 (가비아):"
echo "   가비아 콘솔에서 네임서버를 Route53 NS로 변경"
echo ""
echo "6. NLB 확인:"
echo "   curl -I http://${NLB_DNS}/healthz"