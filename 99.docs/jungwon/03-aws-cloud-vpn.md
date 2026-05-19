# AWS Cloud VPN

## 개요

온프렘 인프라의 확장을 위해 AWS에 HAProxy + WireGuard VPN 구성을 배포합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Cloud                                 │
│                                                                  │
│  ┌──────────────┐                                               │
│  │  Route53     │  domain.example.com                           │
│  │  (DNS)       │       ↓                                       │
│  └──────────────┘                                               │
│         │                                                        │
│         ↓                                                        │
│  ┌──────────────┐                                               │
│  │  NLB         │  TCP 80/443                                   │
│  │  (Load       │       ↓                                       │
│  │   Balancer)  │                                               │
│  └──────────────┘                                               │
│         │                                                        │
│         ↓                                                        │
│  ┌──────────────┐    ┌──────────────┐                          │
│  │  HAProxy #1  │    │  HAProxy #2  │  t3.micro (Free Tier)   │
│  │  EC2         │    │  EC2         │                          │
│  │  (AZ-A)      │    │  (AZ-B)      │                          │
│  │              │    │              │                          │
│  │  WG Client   │────│  WG Client   │                          │
│  └──────────────┘    └──────────────┘                          │
│         │                    │                                   │
│         └────────────────────┘                                   │
│                  │                                                │
│                  ↓                                                │
│  ┌──────────────┐                                               │
│  │  VPN Server  │  WireGuard Server                            │
│  │  EC2 + EIP   │  UDP 51820                                   │
│  │              │                                               │
│  └──────────────┘                                               │
│         │                                                        │
└─────────┼────────────────────────────────────────────────────────┘
          │ WireGuard VPN Tunnel
          ↓
┌─────────────────────────────────────────────────────────────────┐
│                      On-Premises                                 │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐                          │
│  │  App Server  │    │  App Server  │                          │
│  │  #1          │    │  #2          │                          │
│  │  172.16.30.x │    │  172.16.30.x │                          │
│  └──────────────┘    └──────────────┘                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 구성 요소

### AWS 리소스

| 리소스        | 타입                     | 설명                          |
| ------------- | ------------------------ | ----------------------------- |
| VPC           | 10.0.0.0/16              | AWS VPC                       |
| Public Subnet | 10.0.1.0/24, 10.0.2.0/24 | 2개 AZ                        |
| HAProxy EC2   | t3.micro x 2             | 프리티어, HAProxy + WG Client |
| VPN EC2       | t3.micro + EIP           | WireGuard Server              |
| NLB           | Network Load Balancer    | TCP 80/443                    |
| Route53       | DNS                      | 도메인 → NLB                  |
| SSH Key       | RSA 4096                 | 자동 생성                     |

### 네트워크 구성

```
AWS VPC: 10.0.0.0/16
├── Public Subnet AZ-A: 10.0.1.0/24
│   ├── HAProxy EC2 #1
│   └── VPN Server EC2
└── Public Subnet AZ-B: 10.0.2.0/24
    └── HAProxy EC2 #2

WireGuard VPN Network: 10.100.0.0/24
├── VPN Server: 10.100.0.1
├── HAProxy #1: 10.100.0.2
└── HAProxy #2: 10.100.0.3

On-Premises: 172.16.0.0/16
```

## 디렉토리 구조

```
02.terraform/
├── modules/aws/
│   ├── vpc/           # VPC, Subnet, IGW, Route Table
│   ├── ec2/           # HAProxy EC2 instances
│   ├── nlb/           # Network Load Balancer
│   ├── route53/       # DNS Record
│   ├── wireguard/     # VPN Server EC2 + EIP
│   └── keypair/       # SSH Key 자동 생성
│
└── env/aws/
    ├── main.tf        # Module orchestration
    ├── variables.tf   # Input variables
    ├── outputs.tf     # Output values
    ├── terraform.tfvars       # Configuration
    └── terraform.tfvars.example

03.ansible/workspace/
├── roles/
│   ├── wireguard/     # VPN Server 설정
│   │   ├── tasks/
│   │   ├── templates/
│   │   ├── defaults/
│   │   └── handlers/
│   │
│   └── aws_haproxy/   # HAProxy + WG Client
│       ├── tasks/
│       ├── templates/
│       ├── defaults/
│       └── handlers/
│
├── inventories/aws/
│   ├── hosts.yml
│   └── group_vars/
│       ├── aws_haproxy.yml
│       ├── aws_vpn.yml
│       └── vault.yml
│
├── playbooks/
│   └── aws_haproxy.yml
│
└── onprem-wireguard-client.conf.example

deploy-aws.sh          # One-click deployment script
```

## 배포 가이드

### 1. Terraform 변수 설정

```bash
cd 02.terraform/env/aws

# terraform.tfvars 생성
cp terraform.tfvars.example terraform.tfvars

# 변수 수정
vim terraform.tfvars
```

**terraform.tfvars:**

```hcl
name              = "kosa-proxy"
aws_region        = "ap-northeast-2"
instance_type     = "t3.micro"
domain_name       = "your-domain.com"
record_name       = "proxy.your-domain.com"
onprem_cidr_block = "172.16.0.0/16"
```

### 2. 인프라 배포

```bash
# 원클릭 배포
./deploy-aws.sh

# 또는 수동 배포
cd 02.terraform/env/aws
terraform init
terraform plan
terraform apply
```

### 3. VPN 서버 배포

```bash
cd 03.ansible/workspace

# VPN 서버 WireGuard 설정
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_vpn
```

### 4. VPN Public Key 확인

```bash
# VPN 서버의 WireGuard public key 확인
VPN_IP=<VPN_EIP_FROM_TERRAFORM_OUTPUT>
ssh -i kosa-proxy-key.pem ec2-user@$VPN_IP 'cat /etc/wireguard/public.key'

# 출력된 public key를 vault.yml의 vault_vpn_server_public_key에 설정
```

### 5. 온프렘 WireGuard 설정

**온프렘 서버에서 키 생성:**

```bash
# WireGuard 키 생성
wg genkey | tee private.key | wg pubkey > public.key

# public key 내용을 vault.yml의 vault_onprem_peer_public_key에 설정
cat public.key
```

**온프렘 WireGuard 클라이언트 설정 (/etc/wireguard/wg0.conf):**

```ini
[Interface]
Address = 10.100.0.10/24
PrivateKey = <ONPREM_PRIVATE_KEY>
ListenPort = 51820

[Peer]
PublicKey = <AWS_VPN_PUBLIC_KEY>
Endpoint = <AWS_VPN_EIP>:51820
AllowedIPs = 10.0.0.0/16, 10.100.0.0/24
PersistentKeepalive = 25
```

```bash
# WireGuard 시작
wg-quick up wg0
```

### 6. HAProxy 배포

```bash
cd 03.ansible/workspace

# vault.yml 업데이트
vim inventories/aws/group_vars/vault.yml

# vault_vpn_server_public_key: <AWS VPN PUBLIC KEY>
# vault_onprem_peer_public_key: <ONPREM PUBLIC KEY>

# HAProxy 배포
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_haproxy
```

### 7. HAProxy 대상 서버 설정

**inventories/aws/group_vars/aws_haproxy.yml:**

```yaml
onprem_servers:
  - name: onprem-app-1
    ip: 172.16.30.100
    port: 80
  - name: onprem-app-2
    ip: 172.16.30.101
    port: 80

onprem_servers_https:
  - name: onprem-app-1
    ip: 172.16.30.100
    port: 443
  - name: onprem-app-2
    ip: 172.16.30.101
    port: 443
```

## HAProxy 설정

### HTTP Frontend/Backend

```ini
frontend http_front
    bind *:80
    mode tcp
    default_backend onprem_http

backend onprem_http
    balance roundrobin
    option tcp-check
    server onprem-app-1 172.16.30.100:80 check inter 5s fall 3 rise 2
    server onprem-app-2 172.16.30.101:80 check inter 5s fall 3 rise 2
```

### HTTPS Frontend/Backend

```ini
frontend https_front
    bind *:443
    mode tcp
    default_backend onprem_https

backend onprem_https
    balance roundrobin
    option tcp-check
    server onprem-app-1 172.16.30.100:443 check inter 5s fall 3 rise 2
    server onprem-app-2 172.16.30.101:443 check inter 5s fall 3 rise 2
```

### Stats Page

```ini
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:<password>
```

## Ansible Variables

### vault.yml (Sensitive)

```yaml
vault_aws_haproxy_1_ip: "EC2_INSTANCE_1_PUBLIC_IP"
vault_aws_haproxy_2_ip: "EC2_INSTANCE_2_PUBLIC_IP"
vault_aws_vpn_ip: "VPN_INSTANCE_PUBLIC_IP"
vault_haproxy_stats_pass: "SECURE_PASSWORD"
vault_ssh_key_path: "../../kosa-proxy-key.pem"

vault_onprem_peer_public_key: "ONPREM_WIREGUARD_PUBLIC_KEY"
vault_onprem_peer_allowed_ips: "172.16.0.0/16"
vault_onprem_peer_endpoint: ""

vault_wireguard_client_ip: "10.100.0.2/24"
vault_vpn_server_public_key: "AWS_VPN_SERVER_PUBLIC_KEY"
```

### aws_haproxy.yml

```yaml
onprem_servers:
  - name: onprem-app-1
    ip: 172.16.30.100
    port: 80
  - name: onprem-app-2
    ip: 172.16.30.101
    port: 80

onprem_servers_https:
  - name: onprem-app-1
    ip: 172.16.30.100
    port: 443
  - name: onprem-app-2
    ip: 172.16.30.101
    port: 443

haproxy_stats_user: admin
haproxy_stats_pass: "{{ vault_haproxy_stats_pass }}"

wireguard_client_ip: "{{ vault_wireguard_client_ip }}"
vpn_server_public_key: "{{ vault_vpn_server_public_key }}"
vpn_server_endpoint: "{{ vault_aws_vpn_ip }}"
onprem_cidr: "172.16.0.0/16"
```

## 검증

### VPN 연결 확인

```bash
# VPN 서버에서 연결 상태 확인
ssh -i kosa-proxy-key.pem ec2-user@$VPN_IP 'wg show'

# HAProxy EC2에서 VPN 연결 확인
ssh -i kosa-proxy-key.pem ec2-user@$HAProxy_IP 'wg show'
ping 172.16.30.100
```

### HAProxy 상태 확인

```bash
# HAProxy Stats Page
http://<HAProxy_IP>:8404/stats

# NLB DNS
curl http://<NLB_DNS_NAME>

# Route53 Domain
curl http://proxy.your-domain.com
```

### 로그 확인

```bash
# HAProxy 로그
ssh -i kosa-proxy-key.pem ec2-user@$HAProxy_IP 'tail -f /var/log/haproxy.log'

# WireGuard 로그
ssh -i kosa-proxy-key.pem ec2-user@$VPN_IP 'journalctl -u wg-quick@wg0 -f'
```

## 비용 (Free Tier)

| 리소스           | 비용               |
| ---------------- | ------------------ |
| EC2 t3.micro x 3 | Free Tier (12개월) |
| EIP              | Free (1개)         |
| NLB              | ~$0.02/hour        |
| Route53          | ~$0.50/월          |
| Data Transfer    | ~$0.09/GB          |

**예상 월 비용:** ~$20-30 (Free Tier 적용)

## 트러블슈팅

### VPN 연결 문제

```bash
# WireGuard 상태 확인
wg show

# WireGuard 재시작
systemctl restart wg-quick@wg0

# UDP 포트 확인
netstat -ulnp | grep 51820
```

### HAProxy 문제

```bash
# HAProxy 상태 확인
systemctl status haproxy

# HAProxy 설정 검증
haproxy -c -f /etc/haproxy/haproxy.cfg

# HAProxy 재시작
systemctl restart haproxy
```

### 네트워크 라우팅

```bash
# 라우팅 테이블 확인
ip route show

# WireGuard 인터페이스 확인
ip link show wg0
```

## 참고

- [WireGuard Documentation](https://www.wireguard.com/)
- [HAProxy Documentation](https://www.haproxy.org/)
- [AWS NLB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
