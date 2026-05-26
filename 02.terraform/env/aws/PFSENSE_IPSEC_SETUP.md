# pfSense IPsec VPN Setup Guide for AWS Site-to-Site VPN

> **목적**: AWS VPC (10.20.0.0/16) ↔ 온프레미스 (172.16.0.0/12) IPsec 터널 구성

---

## 1. 개요

이 문서는 Terraform으로 생성된 AWS VPN 리소스를 pfSense에 연결하는 방법을 설명합니다.

### 토폴로지

```
온프레미스                              AWS
────────────────                        ────────────────
[172.16.0.0/12]                        [10.20.0.0/16]
    │                                      │
pfSense WAN                              VGW
    │                                      │
TP-Link NAT ── UDP 500/4500 ──────────── VPN Connection
    │                                      │
125.131.208.229                          Tunnel 1: 43.x.x.x
(공인 IP)                                Tunnel 2: 54.x.x.x
                                         (AWS Outside IPs)
```

### 필요 정보 (Terraform Output)

```bash
cd 02.terraform/env/aws
terraform output

# 필요한 값들:
# - vpn_tunnel1_address    → pfSense Phase 1 Remote Gateway (터널 1)
# - vpn_tunnel2_address    → pfSense Phase 1 Remote Gateway (터널 2)
# - vpn_tunnel1_preshared_key → Phase 1 PSK (터널 1)
# - vpn_tunnel2_preshared_key → Phase 1 PSK (터널 2)
# - aws_vpc_cidr          → Phase 2 Remote Network (10.20.0.0/16)
# - onprem_cidr           → Phase 2 Local Network (172.16.0.0/12)
```

---

## 2. Terraform 실행

### 2.1 terraform.tfvars 설정

```hcl
# Customer Gateway IP (TP-Link ER605 공인 IP)
# 온프레에서 curl ifconfig.me로 확인
customer_gateway_ip = "125.131.208.229"  # 실제 공인 IP 입력

# On-Prem CIDR (모든 VLAN 포함)
onprem_cidr_block = "172.16.0.0/12"

# NAT Gateway HA (비용 vs 가용성)
nat_gateway_per_az = true  # AZ당 1개 (~$64/월) 또는 false (~$32/월)
```

### 2.2 Terraform 실행

```bash
cd 02.terraform/env/aws
terraform init
terraform plan
terraform apply
```

### 2.3 VPN Configuration 다운로드

```bash
# VPN 설정 XML 다운로드
terraform output -raw vpn_customer_gateway_configuration > vpn-configuration.xml

# 또는 deploy 스크립트 실행 시 자동 다운로드
./aws-deploy.sh
```

---

## 3. pfSense IPsec Phase 1 설정 (터널 1)

pfSense WebUI 접속 → **VPN → IPsec → Tunnels → Add P1**

### 3.1 Phase 1 기본 설정

| 설정 항목 | 값 |
|----------|-----|
| Key Exchange Version | **IKEv1** |
| Internet Protocol | IPv4 |
| Interface | WAN |
| Remote Gateway | `<vpn_tunnel1_address>` (terraform output) |
| Authentication Method | Mutual PSK |
| My Identifier | My IP address |
| Peer Identifier | Peer IP address |
| Pre-Shared Key | `<vpn_tunnel1_preshared_key>` (terraform output -raw) |

### 3.2 IKE Proposal (Phase 1)

AWS VPN 기본값과 일치해야 합니다:

| 설정 항목 | 값 |
|----------|-----|
| Encryption Algorithm | AES-256-CBC 또는 AES-128-CBC |
| Hash Algorithm | SHA1 |
| DH Group | 2 (1024 bit) |
| Lifetime | 28800 seconds |

### 3.3 NAT Traversal (필수!)

pfSense가 NAT 뒤에 있으므로 설정:

| 설정 항목 | 값 |
|----------|-----|
| NAT Traversal | **Force** |
| Dead Peer Detection | Enable |
| DPD Delay | 10 |
| DPD Max Retries | 3 |

### 3.4 Phase 1 완료 후

- **Save** 클릭
- **Apply Changes** 클릭

---

## 4. pfSense IPsec Phase 2 설정 (터널 1)

방금 만든 Phase 1 옆 → **"+ Show Phase 2 Entries" → Add P2**

### 4.1 Phase 2 기본 설정

| 설정 항목 | 값 |
|----------|-----|
| Mode | Tunnel IPv4 |
| Local Network | `172.16.0.0/12` (Type: Network) |
| Remote Network | `10.20.0.0/16` (Type: Network) |
| Protocol | ESP |

### 4.2 IPsec Proposal (Phase 2)

| 설정 항목 | 값 |
|----------|-----|
| Encryption Algorithm | AES-256-CBC 또는 AES-128-CBC |
| Hash Algorithm | SHA1 |
| PFS Key Group | 2 |
| Lifetime | 3600 seconds |

### 4.3 Phase 2 완료 후

- **Save** 클릭
- **Apply Changes** 클릭

---

## 5. 터널 2 설정 (HA)

터널 1과 동일하게 터널 2도 설정:

- Phase 1 Remote Gateway: `<vpn_tunnel2_address>`
- Phase 1 PSK: `<vpn_tunnel2_preshared_key>`
- Phase 2 설정은 동일

---

## 6. pfSense Firewall 룰

**Firewall → Rules → IPsec → Add**

### 6.1 AWS → 온프레 허용

| 설정 항목 | 값 |
|----------|-----|
| Action | Pass |
| Interface | IPsec |
| Protocol | Any |
| Source | `10.20.0.0/16` |
| Destination | Any (또는 필요한 대역) |
| Description | Allow AWS VPC to on-prem |

### 6.2 온프레 → AWS 허용 (필요시)

| 설정 항목 | 값 |
|----------|-----|
| Action | Pass |
| Interface | IPsec |
| Protocol | Any |
| Source | `172.16.0.0/12` |
| Destination | `10.20.0.0/16` |
| Description | Allow on-prem to AWS VPC |

---

## 7. pfSense Outbound NAT Bypass (핵심!)

**이 설정이 없으면 터널은 UP이지만 ping이 안 됩니다.**

### 7.1 Outbound NAT 모드 변경

**Firewall → NAT → Outbound**

1. Mode: **Hybrid Outbound NAT** 선택
2. **Save** → **Apply Changes**

### 7.2 Bypass 룰 추가 (가장 위에 위치)

**Mappings → Add (맨 위로)**

| 설정 항목 | 값 |
|----------|-----|
| Interface | WAN |
| Source | `172.16.0.0/12` |
| Destination | `10.20.0.0/16` |
| Translation | **No NAT** (체크) |
| Description | Bypass NAT for AWS VPC via IPsec |

### 7.3 왜 필요한가?

pfSense 기본 동작:
- 모든 outbound 트래픽을 WAN IP로 source-NAT
- IPsec 터널 내 트래픽은 원본 src IP 유지 필요
- NAT 되면 src IP가 pfSense WAN IP로 변경 → AWS VGW의 Traffic Selector와 불일치 → drop

---

## 8. 터널 연결 시작

**Status → IPsec**

pfSense는 NAT 뒤에 있으므로 **initiator** 역할을 해야 합니다:

1. Tunnel 1 옆 → **Connect P1 and P2s** 클릭
2. Tunnel 2 옆 → **Connect P1 and P2s** 클릭
3. 1-2분 후 양쪽 터널이 **ESTABLISHED** 상태로 변경

---

## 9. 온프레 라우팅

AWS 대역으로 가는 트래픽이 pfSense로 전달되어야 합니다.

### 9.1 온프레 라우터 (TP-Link ER605)

Static Route 추가:

| 설정 항목 | 값 |
|----------|-----|
| Destination | `10.20.0.0/16` |
| Subnet Mask | `255.255.0.0` |
| Next Hop | pfSense LAN IP (예: `172.16.21.110`) |

### 9.2 pfSense LAN 클라이언트

pfSense가 DHCP 서버라면:
- DHCP → Additional BOOTP/DHCP Options
- Option 121 (Classless Static Route) 추가
- Route: `10.20.0.0/16 → pfSense LAN IP`

---

## 10. 검증

### 10.1 pfSense에서 터널 상태 확인

```bash
# Shell 접속
ipsec statusall

# 또는 WebUI
Status → IPsec → 양쪽 터널 ESTABLISHED 확인
```

### 10.2 AWS에서 VPN 상태 확인

```bash
AWS_REGION=ap-northeast-2
VPN_ID=$(terraform output -raw vpn_connection_id)

aws ec2 describe-vpn-connections \
  --region ${AWS_REGION} \
  --vpn-connection-ids ${VPN_ID} \
  --query 'VpnConnections[0].VgwTelemetry[*].[OutsideIpAddress,Status,StatusMessage]' \
  --output table
```

### 10.3 온프레 bastion에서 AWS ping

```bash
# bastion (172.16.24.10)에서
ping -c 5 10.20.10.130  # HAProxy EC2 private IP
ping -c 5 10.20.20.140  # HAProxy EC2 private IP

# 6ms latency, 0% packet loss → 성공
```

### 10.4 AWS EC2에서 온프레 ping (SSM 접속)

```bash
# SSM Session Manager로 EC2 접속 후
ping -c 5 172.16.24.10  # bastion
ping -c 5 172.16.30.1   # 온프레 라우터

# 양방향 통신 성공 → VPN 완성
```

---

## 11. 트러블슈팅

### 11.1 터널 UP인데 ping 안 됨

**진단 순서**:

1. **AWS Route Propagation 확인**
   ```bash
   # Private Route Table에 172.16.0.0/12 → vgw 있는지
   aws ec2 describe-route-tables --filters Name=vpc-id,Values=<vpc_id>
   ```

2. **pfSense Outbound NAT Bypass 확인**
   ```bash
   # pfSense Shell
   tcpdump -i wan -n udp port 500 or port 4500
   # src IP가 192.168.x.x (pfSense WAN)이면 NAT 됨 → bypass 룰 추가 필요
   ```

3. **Security Group 확인**
   - AWS EC2 SG: Inbound ICMP from 172.16.0.0/12 허용
   - pfSense IPsec Rule: Pass from 10.20.0.0/16

4. **State Table Reset**
   - pfSense → Diagnostics → States → Reset states

### 11.2 Phase 1 Negotiation Failed

**원인**:
- IKE 파라미터 불일치 (Encryption, Hash, DH Group)
- NAT-T 설정 안 됨
- PSK 불일치

**해결**:
- vpn-configuration.xml 확인 → pfSense 설정 일치시키기
- NAT Traversal = Force 설정
- PSK 다시 입력 (terraform output -raw)

### 11.3 한 터널만 UP

**원인**: 터널 2 설정 안 됨

**해결**: 터널 2도 Phase 1/Phase 2 설정 후 Connect

---

## 12. pfSense 진단 명령어

```bash
# IPsec 상태
ipsec statusall
ipsec status

# 터널 트래픽
tcpdump -i enc0 -n
tcpdump -i wan -n udp port 500 or port 4500

# State table
pfctl -ss | grep 10.20
pfctl -F state  # Reset states

# IPsec 로그
clog /var/log/ipsec.log
```

---

## 13. AWS CLI 검증 명령어

```bash
# VPN 연결 상태
aws ec2 describe-vpn-connections \
  --region ap-northeast-2 \
  --vpn-connection-ids <vpn_connection_id>

# Route Table 확인
aws ec2 describe-route-tables \
  --region ap-northeast-2 \
  --filters Name=vpc-id,Values=<vpc_id>

# VGW 확인
aws ec2 describe-vpn-gateways \
  --region ap-northeast-2 \
  --vpn-gateway-ids <vgw_id>
```

---

## 14. 설정 값 참조표

| 설정 항목 | Tunnel 1 | Tunnel 2 |
|----------|----------|----------|
| Remote Gateway | `<vpn_tunnel1_address>` | `<vpn_tunnel2_address>` |
| PSK | `<vpn_tunnel1_preshared_key>` | `<vpn_tunnel2_preshared_key>` |
| IKE Version | IKEv1 | IKEv1 |
| Encryption | AES-256-CBC / AES-128-CBC | AES-256-CBC / AES-128-CBC |
| Hash | SHA1 | SHA1 |
| DH Group | 2 | 2 |
| Lifetime (P1) | 28800 | 28800 |
| Lifetime (P2) | 3600 | 3600 |
| Local Network | 172.16.0.0/12 | 172.16.0.0/12 |
| Remote Network | 10.20.0.0/16 | 10.20.0.0/16 |

---

## 15. Terraform Output 가져오기

```bash
cd 02.terraform/env/aws

# 모든 VPN 관련 output
terraform output | grep vpn

# Tunnel 1 Address
terraform output -raw vpn_tunnel1_address

# Tunnel 1 PSK (sensitive)
terraform output -raw vpn_tunnel1_preshared_key

# Tunnel 2 Address
terraform output -raw vpn_tunnel2_address

# Tunnel 2 PSK (sensitive)
terraform output -raw vpn_tunnel2_preshared_key

# AWS VPC CIDR
terraform output -raw aws_vpc_cidr

# On-Prem CIDR
terraform output -raw onprem_cidr

# VPN Configuration XML
terraform output -raw vpn_customer_gateway_configuration > vpn-configuration.xml
```

---

## 16. pfSense WebUI 경로

| 작업 | WebUI 경로 |
|------|------------|
| Phase 1 추가 | VPN → IPsec → Tunnels → Add P1 |
| Phase 2 추가 | VPN → IPsec → Tunnels → P1 → Add P2 |
| 터널 연결 | Status → IPsec → Connect P1 and P2s |
| Firewall 룰 | Firewall → Rules → IPsec → Add |
| NAT Bypass | Firewall → NAT → Outbound → Add |
| 터널 상태 | Status → IPsec |
| State Reset | Diagnostics → States → Reset |

---

## 17. 성공 기준

- pfSense: 양쪽 터널 ESTABLISHED
- AWS Console: Tunnel 1, Tunnel 2 UP
- 온프레 bastion → AWS EC2 ping 성공 (~6ms)
- AWS EC2 → 온프레 bastion ping 성공 (양방향)
- NLB health check: HAProxy healthy

---

## 18. 다음 단계

VPN 완료 후:

1. **RDS Read Replica**: 온프레 Percona → AWS RDS
2. **EKS + Karpenter**: Burst compute 설정
3. **CloudWatch + Lambda**: Burst trigger
4. **Route53 NS 위임**: 가비아 콘솔에서 NS 변경

---

## 부록: VPN Configuration XML 구조

```xml
<vpn_connection>
  <vpn_connection_id>vpn-xxx</vpn_connection_id>
  <customer_gateway_id>cgw-xxx</customer_gateway_id>
  <vpn_gateway_id>vgw-xxx</vpn_gateway_id>
  
  <ipsec_tunnel>
    <tunnel_outside_ip_address>43.x.x.x</tunnel_outside_ip_address>
    <tunnel_inside_ip_address>
      <customer_gateway>169.254.x.x</customer_gateway>
      <vpn_gateway>169.254.x.x</vpn_gateway>
    </tunnel_inside_ip_address>
    <pre_shared_key>xxxxxxxx</pre_shared_key>
    
    <ike>
      <encryption_algorithm>aes-256-cbc</encryption_algorithm>
      <hashing_algorithm>sha1</hashing_algorithm>
      <diffie_hellman_group>2</diffie_hellman_group>
      <lifetime>28800</lifetime>
    </ike>
    
    <ipsec>
      <encryption_algorithm>aes-256-cbc</encryption_algorithm>
      <hashing_algorithm>sha1</hashing_algorithm>
      <lifetime>3600</lifetime>
    </ipsec>
  </ipsec_tunnel>
  
  <!-- Tunnel 2도 동일 구조 -->
</vpn_connection>
```

이 XML에서 IKE/IPsec 파라미터를 확인하여 pfSense 설정을 일치시킵니다.