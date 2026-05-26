# AWS CLI 프로필 설정 가이드

## AWS CLI 프로필 설정 (kosa)

### 1. AWS Credentials 설정

```bash
# AWS CLI credentials 파일
~/.aws/credentials

[kosa]
aws_access_key_id     = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

### 2. AWS Config 설정

```bash
# AWS CLI config 파일
~/.aws/config

[profile kosa]
region = ap-northeast-2
output = json
```

### 3. Terraform 프로필 사용

```hcl
# terraform.tfvars
aws_profile = "kosa"
```

## 프로필 확인

```bash
# 프로필 목록 확인
aws configure list-profiles

# kosa 프로필 테스트
aws ec2 describe-instances --profile kosa --region ap-northeast-2
```

## Terraform 실행

```bash
cd 02.terraform/env/aws

# terraform.tfvars에 aws_profile = "kosa" 설정됨
terraform init
terraform plan
terraform apply
```

## deploy-aws.sh 실행

```bash
./deploy-aws.sh
# 자동으로 kosa 프로필 사용
```