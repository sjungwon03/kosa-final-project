# Terraform IaC Guide

## 1. 개요

Terraform을 사용하여 Proxmox VM, AWS EKS, RDS, ElastiCache 등의 인프라를 코드로 관리합니다.

## 2. Proxmox Terraform

### 2.1 모듈 구조

```
infrastructure/proxmox/
├── provider.tf           # Provider 설정
├── main.tf               # Main configuration
├── modules/
│   ├── network/          # VLAN 설정
│   ├── k8s-masters/      # K8s Master VMs
│   ├── k8s-workers/      # K8s Worker VMs
│   └── database/         # MySQL VMs
└── outputs.tf
```

### 2.2 VLAN 설정

#### Public VLAN (100)
```hcl
network {
  model  = "virtio"
  bridge = "vmbr0"
  tag    = 100  # Public VLAN
}
```

#### K8s Private VLAN (200)
```hcl
network {
  model  = "virtio"
  bridge = "vmbr0"
  tag    = 200  # K8s VLAN
}
```

#### DB Private VLAN (300)
```hcl
network {
  model  = "virtio"
  bridge = "vmbr0"
  tag    = 300  # DB VLAN
}
```

### 2.3 VM 구성

| VM Role       | Count | CPU | RAM  | VLAN    | IP Range      |
|---------------|-------|-----|------|---------|---------------|
| K8s Master    | 3     | 2   | 4GB  | 200, 100| 10.0.2.10-12  |
| K8s Worker    | 6     | 4   | 8GB  | 200     | 10.0.2.20-25  |
| MySQL Master  | 1     | 2   | 4GB  | 300     | 10.0.3.10     |
| MySQL Slave   | 2     | 2   | 4GB  | 300     | 10.0.3.11-12  |

### 2.4 실행

```bash
cd infrastructure/proxmox

# terraform.tfvars 파일 생성
cat > terraform.tfvars <<EOF
proxmox_api_url = "https://pve1.example.com:8006/api2/json"
proxmox_user     = "root@pam"
proxmox_password = "your-password"
ssh_public_key   = "ssh-rsa AAAA..."
EOF

# Terraform 실행
terraform init
terraform plan
terraform apply
```

## 3. AWS Terraform

### 3.1 모듈 구조

```
infrastructure/aws/
├── provider.tf
├── main.tf
├── modules/
│   ├── vpc/              # VPC, Subnets, NAT Gateway
│   ├── eks/              # EKS Cluster, Node Groups
│   ├── rds/              # Aurora MySQL
│   ├── elasticache/      # Redis Cluster
│   ├── s3-cloudfront/    # Frontend CDN
│   └── monitoring/       # CloudWatch
└── outputs.tf
```

### 3.2 VPC Module

```hcl
module "vpc" {
  source = "./modules/vpc"

  cluster_name = "kosa-eks"
  aws_region   = "ap-northeast-2"
  vpc_cidr     = "10.1.0.0/16"

  # Subnets
  # Public:  10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24
  # Private: 10.1.10.0/24, 10.1.11.0/24, 10.1.12.0/24
  # Database:10.1.20.0/24, 10.1.21.0/24, 10.1.22.0/24
}
```

### 3.3 EKS Module

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name = "kosa-eks"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  # Node Group
  instance_types = ["m5.large", "m5.xlarge"]
  min_size       = 0
  max_size       = 10
  desired_size   = 0  # CloudBursting용
}
```

### 3.4 RDS Module

```hcl
module "rds" {
  source = "./modules/rds"

  db_password  = var.db_password
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.database_subnet_ids

  # Aurora MySQL
  engine        = "aurora-mysql"
  engine_version= "8.0.mysql_aurora.3.02.0"
  instance_class= "db.r5.large"
  cluster_count = 2
}
```

### 3.5 ElastiCache Module

```hcl
module "elasticache" {
  source = "./modules/elasticache"

  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.database_subnet_ids

  # Redis Cluster
  engine         = "redis"
  engine_version = "7.0"
  node_type      = "cache.r5.large"
  num_cache_nodes= 2
}
```

### 3.6 실행

```bash
cd infrastructure/aws

# terraform.tfvars 생성
cat > terraform.tfvars <<EOF
aws_region       = "ap-northeast-2"
cluster_name     = "kosa-eks"
db_password      = "your-db-password"
frontend_bucket_name = "kosa-frontend-bucket"
acm_certificate_arn = "arn:aws:acm:..."
EOF

# Terraform 실행
terraform init
terraform plan
terraform apply

# Outputs 확인
terraform output
```

## 4. 상태 관리

### 4.1 Backend 설정

#### Proxmox
```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

#### AWS
```hcl
terraform {
  backend "s3" {
    bucket  = "kosa-terraform-state"
    key     = "aws/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}
```

### 4.2 Remote State

```bash
# Proxmox state 확인
terraform state list

# AWS state 확인 (S3)
terraform state list -backend-config="bucket=kosa-terraform-state"
```

## 5. Variables

### 5.1 Proxmox Variables

| Variable           | Type     | Default      |
|--------------------|----------|--------------|
| proxmox_api_url    | string   | -            |
| proxmox_user       | string   | -            |
| proxmox_password   | string   | -            |
| vlan_public_id     | number   | 100          |
| vlan_k8s_id        | number   | 200          |
| vlan_db_id         | number   | 300          |
| cluster_nodes      | list(string)| ["pve1","pve2","pve3","pve4"] |

### 5.2 AWS Variables

| Variable           | Type     | Default         |
|--------------------|----------|-----------------|
| aws_region         | string   | ap-northeast-2  |
| cluster_name       | string   | kosa-eks        |
| vpc_cidr           | string   | 10.1.0.0/16     |
| db_password        | string   | -               |
| frontend_bucket_name| string  | kosa-frontend   |

## 6. Outputs

### 6.1 Proxmox Outputs
- master_ips: K8s Master IPs
- worker_ips: K8s Worker IPs
- database_ips: MySQL IPs

### 6.2 AWS Outputs
- eks_cluster_endpoint
- rds_endpoint
- redis_endpoint
- cloudfront_domain_name

## 7. Terraform Commands

```bash
# 초기화
terraform init

# Plan 확인
terraform plan

# Apply 실행
terraform apply

# Destroy (리소스 삭제)
terraform destroy

# Output 확인
terraform output

# State 관리
terraform state list
terraform state show module.eks.aws_eks_cluster.kosa_eks
```