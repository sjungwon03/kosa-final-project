# AWS Site-to-Site VPN Quick Reference

> **상세 설정 가이드**: [PFSENSE_IPSEC_SETUP.md](./PFSENSE_IPSEC_SETUP.md)

---

## 1. Terraform 실행

```bash
cd 02.terraform/env/aws

# terraform.tfvars 설정
customer_gateway_ip = "125.131.208.229"  # TP-Link 공인 IP
onprem_cidr_block = "172.16.0.0/12"

# 실행
terraform init
terraform plan
terraform apply
```

## 2. VPN 정보 확인

```bash
# VPN 터널 IP
terraform output vpn_tunnel1_address
terraform output vpn_tunnel2_address

# PSK (sensitive)
terraform output -raw vpn_tunnel1_preshared_key
terraform output -raw vpn_tunnel2_preshared_key

# CIDR
terraform output aws_vpc_cidr   # 10.20.0.0/16
terraform output onprem_cidr    # 172.16.0.0/12

# 전체 XML
terraform output -raw vpn_customer_gateway_configuration > vpn-configuration.xml
```

## 3. pfSense 설정 (핵심 5단계)

1. **Phase 1** (터널 1, 2 각각)
   - Remote Gateway: `<vpn_tunnel_address>`
   - PSK: `<preshared_key>`
   - IKE: AES-256, SHA1, DH Group 2
   - **NAT Traversal: Force**

2. **Phase 2** (터널 1, 2 각각)
   - Local: 172.16.0.0/12
   - Remote: 10.20.0.0/16
   - IPsec: AES-256, SHA1, PFS Group 2

3. **Firewall Rule**
   - Interface: IPsec
   - Source: 10.20.0.0/16
   - Action: Pass

4. **Outbound NAT Bypass** ⭐ 필수
   - Interface: WAN
   - Source: 172.16.0.0/12
   - Dest: 10.20.0.0/16
   - Translation: No NAT

5. **터널 연결**
   - Status → IPsec → Connect P1 and P2s

## 4. 검증

```bash
# 온프레 bastion에서
ping 10.20.10.130  # AWS HAProxy private IP

# AWS EC2에서 (SSM)
ping 172.16.24.10  # 온프레 bastion
```

---

**상세 가이드**: [PFSENSE_IPSEC_SETUP.md](./PFSENSE_IPSEC_SETUP.md)