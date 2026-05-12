# pfSense 방화벽 설치 및 설정 가이드 (초보자용)

작성자: hyeyun

---

## pfSense가 무엇인가요?

pfSense는 방화벽/라우터입니다.

**기능**:
- 방화벽: 네트워크 트래픽 제어
- 라우팅: VLAN 간 통신
- NAT: 외부 → 내부 접근 설정
- VPN: 외부에서 내부 접속

---

## 네트워크 구성

### VLAN 구성

이 프로젝트는 4개 VLAN으로 네트워크 분리:

| VLAN | 이름    | IP 대역        | 용도               |
|------|---------|----------------|--------------------|
| 10   | 공용망  | 192.168.10.0/24 | 사용자, PC         |
| 20   | DMZ     | 172.16.20.0/24 | HAProxy, ProxySQL  |
| 30   | 내부망  | 172.16.30.0/24 | Percona, K8s       |
| 40   | 관리망  | 192.168.40.0/24 | Proxmox, 관리자    |

### 네트워크 구성도

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
       │   → HAProxy (172.16.20.20-21)
       │   → ProxySQL (172.16.20.25-26)
       │
       ├─ VLAN 30 (내부망)
       │   172.16.30.0/24
       │   → Percona (172.16.30.10-12)
       │   → Kubernetes (ArgoCD, GitLab, Harbor)
       │
       └─ VLAN 40 (관리망)
           192.168.40.0/24
           → Proxmox (192.168.40.21-24)
```

---

## pfSense 설치

### Step 1: VM 생성

Proxmox에서 pfSense VM 생성:

| 설정    | 값            |
|---------|---------------|
| CPU     | 2 cores       |
| Memory  | 4GB           |
| Disk    | 20GB          |
| Network | vmbr1 (VLAN aware) |
| ISO     | pfSense ISO   |

### Step 2: pfSense 설치

1. VM Start
2. Console에서 pfSense 설치
3. Install pfSense
4. Reboot

### Step 3: 초기 설정

Console에서:

```
1) Set interface IP address
2) Enter LAN interface name: vmx0
3) Enter LAN IP address: 192.168.1.1
4) Enter subnet mask: 24
5) Enable DHCP: n
6) Reboot
```

### Step 4: Web UI 접속

```
URL: https://192.168.1.1
Username: admin
Password: pfsense

# 비밀번호 변경
1) User Manager → admin → Password
```

---

## VLAN 설정

### Step 1: VLAN 생성

pfSense Web UI:

```
1. Interfaces → VLANs → Add

Parent Interface: vmx0 (또는 WAN interface)
VLAN Tag: 10
Description: Public_Network
→ Save

VLAN Tag: 20
Description: DMZ_Network
→ Save

VLAN Tag: 30
Description: Internal_Network
→ Save

VLAN Tag: 40
Description: Management_Network
→ Save
```

### Step 2: Interface Assignments

```
1. Interfaces → Assignments

VLAN 10 → Add → 이름: PUBLIC
VLAN 20 → Add → 이름: DMZ
VLAN 30 → Add → 이름: INTERNAL
VLAN 40 → Add → 이름: MGMT

→ Save
```

### Step 3: Interface IP 설정

#### VLAN 10 (공용망)

```
1. Interfaces → PUBLIC
2. Enable: ☑
3. IPv4: Static
4. IP Address: 192.168.10.1/24
5. Save → Apply Changes
```

#### VLAN 20 (DMZ)

```
1. Interfaces → DMZ
2. Enable: ☑
3. IPv4: Static
4. IP Address: 172.16.20.1/24
5. Save → Apply Changes
```

#### VLAN 30 (내부망)

```
1. Interfaces → INTERNAL
2. Enable: ☑
3. IPv4: Static
4. IP Address: 172.16.30.1/24
5. Save → Apply Changes
```

#### VLAN 40 (관리망)

```
1. Interfaces → MGMT
2. Enable: ☑
3. IPv4: Static
4. IP Address: 192.168.40.1/24
5. Save → Apply Changes
```

### Step 4: VLAN 확인

```
1. Interfaces → Assignments
2. 모든 VLAN interface 확인

ping 테스트:
# pfSense shell에서
ping 192.168.10.1
ping 172.16.20.1
ping 172.16.30.1
ping 192.168.40.1
```

---

## 방화벽 규칙 설정

### 기본 개념

- **Pass**: 트래픽 허용
- **Block**: 트래픽 차단
- **Rule 순서**: 위에서 아래로 적용

### VLAN 20 (DMZ) → VLAN 30 (내부망) 규칙

DB 접근을 허용합니다.

```
1. Firewall → Rules → DMZ → Add

Action: Pass
Protocol: TCP
Source: DMZ net (172.16.20.0/24)
Destination: INTERNAL net (172.16.30.10-172.16.30.12)
Port: 3306 (MySQL)
Description: DMZ to Percona MySQL
→ Save → Apply Changes
```

### VLAN 30 (내부망) 통신 규칙

내부망 내 모든 통신 허용.

```
1. Firewall → Rules → INTERNAL → Add

Action: Pass
Protocol: Any
Source: INTERNAL net (172.16.30.0/24)
Destination: INTERNAL net
Port: Any
Description: Internal network communication
→ Save → Apply Changes
```

### VLAN 40 (관리망) → 모든 VLAN 규칙

관리자가 모든 네트워크 접근.

```
1. Firewall → Rules → MGMT → Add

Action: Pass
Protocol: Any
Source: MGMT net (192.168.40.0/24)
Destination: Any
Port: Any
Description: Management full access
→ Save → Apply Changes
```

### Block 규칙

#### VLAN 10 → VLAN 30 Block

```
1. Firewall → Rules → PUBLIC → Add

Action: Block
Protocol: Any
Source: PUBLIC net
Destination: INTERNAL net
Port: Any
Description: Block public to internal
→ Save → Apply Changes
```

---

## 방화벽 규칙 확인

### Rule Order 확인

```
1. Firewall → Rules → [Interface]
2. 규칙 순서 확인
3. Drag & Drop으로 순서 변경 가능
```

### Traffic Test

```bash
# DMZ에서 Percona 접근 테스트
ssh kosa@172.16.20.20
mysql -h172.16.30.10 -P3306 -u root -p
# 성공하면 Pass rule 작동

# 공용망에서 내부망 접근 테스트
ssh kosa@192.168.10.100
ping 172.16.30.10
# 실패하면 Block rule 작동
```

---

## NAT 설정 (Port Forwarding)

외부에서 내부 서비스 접근 설정.

### ArgoCD Port Forward

```
1. Firewall → NAT → Port Forward → Add

Interface: WAN (또는 PUBLIC)
Protocol: TCP
External Port: 80
Internal IP: 172.16.30.x (K8s Ingress)
Internal Port: 80
Description: ArgoCD HTTP
→ Save → Apply Changes
```

### GitLab Port Forward

```
Interface: WAN
Protocol: TCP
External Port: 443
Internal IP: 172.16.30.x (K8s Ingress)
Internal Port: 443
Description: GitLab HTTPS
→ Save → Apply Changes
```

---

## 문제 해결

### VLAN 통신 안됨

```
1. Firewall → Rules → [Interface]
2. Pass rule 확인
3. Apply Changes
```

### Traffic 차단됨

```
1. Status → System Logs → Firewall
2. Blocked traffic 확인
3. Rule 추가
```

---

## 참고 링크

1. **pfSense 공식 문서**: https://docs.pfsense.org/
2. **VLAN 설정**: https://docs.pfsense.org/index.php/VLANs

---

## 다음 단계

1. 방화벽 규칙 상세 설정 → 02-pfsense-firewall-rules.md
2. NAT 설정 → 03-pfsense-nat-setup.md