#!/bin/bash
set -e

PROJECT_ROOT="/Users/sloki9637/Dev/kosa-final-project"
TERRAFORM_DIR="$PROJECT_ROOT/02.terraform/env/aws"
ANSIBLE_DIR="$PROJECT_ROOT/03.ansible/workspace"
EKS_MANIFEST="$PROJECT_ROOT/04.k8s/manifests/eks/web-app/deployment.yaml"
EKS_CLUSTER_NAME="kosa-proxy-eks"
REGION="ap-northeast-2"
AWS_PROFILE="kosa"
export AWS_PROFILE

echo "========================================"
echo "  AWS Hybrid Deployment (Full Stack)"
echo "========================================"
echo ""

cd "$TERRAFORM_DIR"

echo "[1/6] Terraform Init"
terraform init

echo ""
echo "[2/6] Terraform Plan"
terraform plan -out=tfplan

echo ""
echo "[3/6] Terraform Apply"
terraform apply tfplan

echo ""
echo "[4/6] Get HAProxy NLB IP"
HAPROXY_NLB=$(terraform output -raw nlb_dns_name 2>/dev/null || aws elbv2 describe-load-balancers --region $REGION --profile kosa --query 'LoadBalancers[?contains(LoadBalancerName, `kosa-proxy`)].DNSName' --output text)
echo "HAProxy NLB: $HAPROXY_NLB"

echo ""
echo "[5/6] Ansible - Configure HAProxy (Web + DB Proxy)"
cd "$ANSIBLE_DIR"
ansible-playbook -i inventories/aws playbooks/aws_haproxy.yml

echo ""
echo "[6/6] Deploy to EKS Fargate"
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $REGION --profile kosa --alias eks-cluster

kubectl create namespace kosa --dry-run=client -o yaml | kubectl apply -f -

sed "s|HAPROXY_NLB_PLACEHOLDER|$HAPROXY_NLB|g" "$EKS_MANIFEST" | kubectl apply -f -

echo ""
echo "Waiting for Fargate pods..."
kubectl -n kosa rollout status deployment web-app --timeout=180s

EKS_NLB=$(kubectl -n kosa get svc web-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "EKS NLB: $EKS_NLB"

echo ""
echo "Configuring HAProxy with EKS backup backend..."
cat > "$ANSIBLE_DIR/inventories/aws/group_vars/aws_haproxy.yml" << EOF
---
ansible_python_interpreter: /usr/bin/python3

onprem_servers:
  - name: onprem-lb
    ip: 172.16.30.205
    port: 80

eks_servers:
  - name: eks-backup
    ip: "$EKS_NLB"
    port: 80

haproxy_stats_user: admin
haproxy_stats_pass: "{{ vault_haproxy_stats_pass }}"

db_proxy_enabled: true
db_proxy_port: 3306
db_servers:
  - name: onprem-mysql
    ip: "{{ vault_db_ip | default('172.16.30.100') }}"
    port: "{{ vault_db_port | default(3306) }}"
EOF

ansible-playbook -i inventories/aws playbooks/aws_haproxy.yml

echo ""
echo "========================================"
echo "  Deployment Complete!"
echo "========================================"
echo ""
echo "Web Traffic (Active-Passive Failover):"
echo "  Primary:  Onprem -> 172.16.30.205:80"
echo "  Backup:   EKS    -> $EKS_NLB:80"
echo ""
echo "DB Access (VPN via HAProxy):"
echo "  EKS Pods -> HAProxy:3306 -> VPN -> Onprem MySQL"
echo ""
echo "HAProxy Stats: http://$HAPROXY_NLB:8404/stats"
echo ""
kubectl -n kosa get pods -o wide
kubectl -n kosa get svc