# pfSense 방화벽 설치 가이드

작성자: hyeyun

---

## 문서 목록

### 1. [pfSense 설치 및 VLAN 설정](01-pfsense-install-setup.md)

pfSense 방화벽 설치 및 VLAN 구성

- pfSense VM 생성
- 초기 설정
- VLAN 생성 (10, 20, 30, 40)
- Interface IP 설정

### 2. [방화벽 규칙 상세 설정](02-pfsense-firewall-rules.md)

VLAN 간 트래픽 제어 규칙

- Alias 생성 (Percona_Nodes, DB_Ports)
- DMZ → 내부망 규칙 (MySQL)
- 내부망 통신 규칙
- 관리망 접근 규칙

### 3. [NAT/Port Forward 설정](03-pfsense-nat-setup.md)

외부 → 내부 서비스 접근 설정

- ArgoCD Port Forward
- GitLab Port Forward
- Harbor Port Forward
- HAProxy Port Forward (MySQL)

### 4. [문제 해결](04-pfsense-troubleshooting.md)

pfSense 문제 해결 방법

- VLAN 문제
- 방화벽 문제
- NAT 문제
- Diagnostic Tools

---

## VLAN 구성

| VLAN | 이름    | IP 대역        | Gateway      | 용도               |
|------|---------|----------------|--------------|--------------------|
| 10   | 공용망  | 192.168.10.0/24| 192.168.10.1 | 사용자, PC         |
| 20   | DMZ     | 172.16.20.0/24 | 172.16.20.1  | HAProxy, ProxySQL  |
| 30   | 내부망  | 172.16.30.0/24 | 172.16.30.1  | Percona, K8s       |
| 40   | 관리망  | 192.168.40.0/24| 192.168.40.1 | Proxmox, 관리자    |

---

## 네트워크 구성도

```
┌─────────────┐
│   pfSense   │
│   Firewall  │
└─────────────┘
       │
       ├─ VLAN 10 (공용망)
       │   192.168.10.0/24
       │   → 사용자 PC
       │
       ├─ VLAN 20 (DMZ)
       │   172.16.20.0/24
       │   → HAProxy-1 (172.16.20.20)
       │   → HAProxy-2 (172.16.20.21)
       │   → ProxySQL-1 (172.16.20.25)
       │   → ProxySQL-2 (172.16.20.26)
       │
       ├─ VLAN 30 (내부망)
       │   172.16.30.0/24
       │   → Percona pxc-1 (172.16.30.10)
       │   → Percona pxc-2 (172.16.30.11)
       │   → Percona pxc-3 (172.16.30.12)
       │   → Kubernetes Cluster
       │      - ArgoCD
       │      - GitLab
       │      - Harbor
       │
       └─ VLAN 40 (관리망)
           192.168.40.0/24
           → Proxmox kosa21 (192.168.40.21)
           → Proxmox kosa22 (192.168.40.22)
           → Proxmox kosa23 (192.168.40.23)
           → Proxmox kosa24 (192.168.40.24)
```

---

## 설정 순서

```
1. pfSense 설치 (01-pfsense-install-setup.md)
   └── VM 생성
   └── VLAN 생성
   └── Interface IP 설정
         ↓
2. 방화벽 규칙 설정 (02-pfsense-firewall-rules.md)
   └── Alias 생성
   └── VLAN 간 규칙
         ↓
3. NAT/Port Forward 설정 (03-pfsense-nat-setup.md)
   └── 외부 접근 설정
         ↓
4. 테스트 및 문제 해결 (04-pfsense-troubleshooting.md)
```

---

## 참고 링크

1. **pfSense 공식 문서**: https://docs.pfsense.org/
2. **VLAN 설정**: https://docs.pfsense.org/index.php/VLANs
3. **Firewall Rules**: https://docs.pfsense.org/index.php/Firewall_Rule_Basics