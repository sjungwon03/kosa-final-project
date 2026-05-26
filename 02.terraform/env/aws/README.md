# AWS Infrastructure Quick Reference

## 배포 순서

```bash
# 1. Terraform 배포 (인프라 생성)
./deploy-aws.sh

# 2. VPN 서버 WireGuard 설정
cd 03.ansible/workspace
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_vpn

# 3. VPN Public Key 확인
VPN_IP=$(grep vpn_instance_public_ip ../../02.terraform/env/aws/terraform.tfstate | head -1 | cut -d'"' -f4)
ssh -i ../../kosa-proxy-key.pem ec2-user@$VPN_IP 'cat /etc/wireguard/public.key'

# 4. vault.yml 업데이트 (VPN Public Key + 온프렘 Public Key)
vim inventories/aws/group_vars/vault.yml

# 5. HAProxy 배포
ansible-playbook -i inventories/aws/hosts.yml playbooks/aws_haproxy.yml --limit aws_haproxy

# 6. 온프렘 WireGuard 클라이언트 설정
# onprem-wireguard-client.conf.example 참조
```

## SSH 연결

```bash
# SSH Key
KEY=kosa-proxy-key.pem

# HAProxy #1
ssh -i $KEY ec2-user@<HAProxy_1_IP>

# HAProxy #2
ssh -i $KEY ec2-user@<HAProxy_2_IP>

# VPN Server
ssh -i $KEY ec2-user@<VPN_IP>
```

## 주요 명령어

```bash
# WireGuard 상태
wg show

# HAProxy 상태
systemctl status haproxy

# HAProxy Stats
curl http://<IP>:8404/stats

# VPN 연결 테스트
ping 172.16.30.100
```

## 파일 위치

| 파일 | 경로 |
|------|------|
| Terraform tfvars | `02.terraform/env/aws/terraform.tfvars` |
| Ansible vault | `03.ansible/workspace/inventories/aws/group_vars/vault.yml` |
| HAProxy config | `03.ansible/workspace/roles/aws_haproxy/templates/haproxy.cfg.j2` |
| WG client config | `03.ansible/workspace/roles/aws_haproxy/templates/wg0.conf.j2` |
| SSH Key | `kosa-proxy-key.pem` |

## 비용 (Free Tier)

- EC2 t3.micro x 3: **FREE** (12개월)
- EIP: **FREE** (1개)
- NLB: ~$18/월
- Route53: ~$0.50/월
- **예상:** ~$20/월