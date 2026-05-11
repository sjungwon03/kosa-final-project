# VPN 연결 (AWS ↔ 온프레미스)

## 1. 개요

AWS VPN Connection을 사용하여 AWS EKS와 온프레미스 MySQL MHA를 연결합니다.

## 2. VPN 구성

### 2.1 AWS VPN Gateway
- **Type**: Site-to-Site VPN (IPsec)
- **Gateway**: aws_vpn_gateway
- **Customer Gateway**: 온프레미스 VPN Gateway (10.0.1.1)

### 2.2 VPN Connection
- **Connection ID**: aws_vpn_connection
- **Static Routes**: On-premise CIDR (10.0.0.0/8)
- **BGP ASN**: 65000

## 3. 네트워크 구성

### 3.1 온프레미스
```
MySQL MHA (VLAN 300)
├── Master: 10.0.3.10
├── Slave 1: 10.0.3.11
└── Slave 2: 10.0.3.12
```

### 3.2 AWS
```
AWS EKS (VPC 10.1.0.0/16)
├── Private Subnets: 10.1.10.0/24, 10.1.11.0/24, 10.1.12.0/24
└── VPN Route: 10.0.0.0/8 → VPN Gateway
```

## 4. Terraform VPN Module

```hcl
module "vpn" {
  source = "./modules/vpn"

  cluster_name       = "kosa-eks"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  onprem_cidr        = "10.0.0.0/8"
  onprem_vpn_gateway = "10.0.1.1"
}
```

### 4.1 VPN Gateway
```hcl
resource "aws_vpn_gateway" "kosa_vpn_gw" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.cluster_name}-vpn-gateway"
  }
}
```

### 4.2 Customer Gateway
```hcl
resource "aws_customer_gateway" "onprem_gw" {
  bgp_asn    = 65000
  ip_address = var.onprem_vpn_gateway
  type       = "ipsec.1"
}
```

### 4.3 VPN Connection
```hcl
resource "aws_vpn_connection" "kosa_vpn" {
  vpn_gateway_id      = aws_vpn_gateway.kosa_vpn_gw.id
  customer_gateway_id = aws_customer_gateway.onprem_gw.id
  type                = "ipsec.1"
  static_routes_only  = true
}
```

### 4.4 Route
```hcl
resource "aws_route" "vpn_route" {
  route_table_id         = aws_vpn_gateway.kosa_vpn_gw.vpc_id
  destination_cidr_block = var.onprem_cidr
  gateway_id             = aws_vpn_gateway.kosa_vpn_gw.id
}
```

## 5. 온프레미스 VPN Gateway 설정

### 5.1 Proxmox VPN Gateway
- **IP**: 10.0.1.1 (Public VLAN)
- **Software**: StrongSwan 또는 OpenVPN

### 5.2 StrongSwan 설정 (/etc/ipsec.conf)
```
conn aws-vpn
  left=10.0.1.1
  leftsubnet=10.0.0.0/8
  right=<AWS_VPN_GATEWAY_IP>
  rightsubnet=10.1.0.0/16
  authby=secret
  auto=start
```

### 5.3 Pre-shared Key (/etc/ipsec.secrets)
```
<AWS_VPN_GATEWAY_IP> : PSK "YourPSK123"
```

## 6. AWS EKS에서 온프레미스 DB 접근

### 6.1 Kubernetes Service (MySQL)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-onprem
  namespace: kosa
spec:
  type: ExternalName
  externalName: 10.0.3.10
```

### 6.2 Backend Service 환경 변수
```yaml
env:
- name: MYSQL_HOST
  value: "10.0.3.10"  # VPN으로 접근
- name: MYSQL_PORT
  value: "3306"
```

## 7. VPN 상태 확인

### 7.1 AWS VPN Connection 상태
```bash
aws vpn describe-vpn-connections --vpn-connection-ids <connection-id>
```

### 7.2 Route Table 확인
```bash
aws ec2 describe-route-tables --route-table-ids <rt-id>
```

### 7.3 Ping Test (AWS Pod에서)
```bash
kubectl run -it --rm ping-test --image=busybox --restart=Never -- \
  ping 10.0.3.10
```

## 8. Security Group 설정

### 8.1 AWS Security Group
- **Inbound**: 온프레미스 CIDR (10.0.0.0/8) → Port 3306

### 8.2 온프레미스 Firewall
- **Inbound**: AWS VPC CIDR (10.1.0.0/16) → Port 3306

## 9. VPN Monitoring

### 9.1 CloudWatch Metrics
- `VPNConnectionState`
- `TunnelState`
- `TunnelDataIn`
- `TunnelDataOut`

### 9.2 VPN Dashboard
```json
{
  "metrics": [
    ["AWS/VPN", "VPNConnectionState", "VPNConnectionId", "<connection-id>"]
  ]
}
```

## 10. 문제 해결

### 10.1 VPN 연결 실패
```bash
# VPN Connection 재설정
aws vpn reset-vpn-connection --vpn-connection-id <connection-id>

# Customer Gateway IP 확인
ping <onprem-vpn-gateway-ip>
```

### 10.2 Route 문제
```bash
# Route Table 확인
aws ec2 describe-route-tables

# Route 추가
aws ec2 create-route --route-table-id <rt-id> --destination-cidr-block 10.0.0.0/8 --gateway-id <vpn-gw-id>
```

### 10.3 DB 접근 실패
```bash
# Security Group 확인
aws ec2 describe-security-groups --group-ids <sg-id>

# Firewall 확인 (온프레미스)
iptables -L -n
```