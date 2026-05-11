# Percona XtraDB Cluster DMZ/내부망 분리 아키텍처

## 1. 네트워크 구성 개요

### DMZ vs 내부망 분리 이유

**DMZ (172.16.20.x)**:
- 외부에서 접근 가능한 서비스
- HAProxy, ProxySQL 배치
- 애플리케이션 연결 포인트
- 보안: 방화벽으로 내부망과 분리

**내부망 (172.16.30.x)**:
- 외부 접근 불가 (보안)
- Percona 데이터베이스 배치
- HAProxy/ProxySQL만 접근 가능
- 데이터 보호

---

## 2. 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        외부 네트워크                             │
│                    (애플리케이션, 사용자)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         DMZ (VLAN 20)                           │
│                        172.16.20.0/24                           │
│                        Gateway: 172.16.20.1                     │
└─────────────────────────────────────────────────────────────────┘
│                                                                 │
│  HAProxy VIP: 172.16.20.30                                      │
│  ┌──────────────────────────────────────────┐                   │
│  │ haproxy-1 (172.16.20.20) - pve1          │                   │
│  │ haproxy-2 (172.16.20.21) - pve2          │                   │
│  └──────────────────────────────────────────┘                   │
│     Port 3306 (Read) / Port 3307 (Write)                        │
│                                                                 │
│  ProxySQL VIP: 172.16.20.35                                     │
│  ┌──────────────────────────────────────────┐                   │
│  │ proxysql-1 (172.16.20.25) - pve3         │                   │
│  │ proxysql-2 (172.16.20.26) - pve4         │                   │
│  └──────────────────────────────────────────┘                   │
│     Port 6033 (MySQL Proxy)                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (pfSense Firewall Rules)
                              │ DMZ → Internal: Allow MySQL (3306)
                              │ Internal → DMZ: Block
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      내부망 (VLAN 30)                            │
│                       172.16.30.0/24                            │
│                       Gateway: 172.16.30.1                      │
└─────────────────────────────────────────────────────────────────┘
│                                                                 │
│  Percona XtraDB Cluster                                         │
│  ┌──────────────────────────────────────────┐                   │
│  │ pxc-1 (172.16.30.10) - pve1 [Bootstrap]  │                   │
│  │ pxc-2 (172.16.30.11) - pve2              │                   │
│  │ pxc-3 (172.16.30.12) - pve3              │                   │
│  └──────────────────────────────────────────┘                   │
│     Galera Cluster Replication                                  │
│     Port 3306 (MySQL)                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 네트워크 세부 구성

### 3-1. DMZ (172.16.20.x)

**용도**: 외부 접근 가능 서비스 배치

**구성 요소**:
- HAProxy (172.16.20.20-21): 로드밸런서
- ProxySQL (172.16.20.25-26): MySQL 프록시
- VIPs (172.16.20.30, 172.16.20.35): 고가용성 VIP

**VLAN 설정**:
```
VLAN ID: 20
Gateway: 172.16.20.1 (pfSense)
IP Range: 172.16.20.0/24
```
```
애플리케이션 → HAProxy VIP (172.16.20.30:3306)
                ├── 읽기 쿼리 분산
                
애플리케이션 → ProxySQL VIP (172.16.20.35:6033)
                ├── 쿼리 라우팅
                ├── 읽기/쓰기 분리
```

**방화벽 규칙 (DMZ → 내부망)**:
```
Source: DMZ (172.16.20.20-26)
Destination: Internal (172.16.30.10-12)
Port: 3306 (MySQL)
Action: Allow

Source: Internal (172.16.30.10-12)
Destination: DMZ (172.16.20.20-26)
Port: Any
Action: Block
```

### 3-2. 내부망 (172.16.30.x)

**용도**: 데이터베이스 서버 (보안)

**구성 요소**:
- Percona (172.16.30.10-12): MySQL 클러스터

**VLAN 설정**:
```
VLAN ID: 30
Gateway: 172.16.30.1 (pfSense)
IP Range: 172.16.30.0/24
```
```
외부 → Internal: Block (직접 접근 불가)
DMZ → Internal: Allow (MySQL 포트만)
Internal → DMZ: Block (보안)
```

**Galera 복제 통신**:
```
pxc-1 (172.16.30.10) ↔ pxc-2 (172.16.30.11) ↔ pxc-3 (172.16.30.12)
    
포트:
  ├── 3306: MySQL 클라이언트 연결
  ├── 4444: SST (State Snapshot Transfer)
  ├── 4567: Galera 복제
  └── 4568: IST (Incremental State Transfer)
```

---

## 4. pfSense 설정

### 4-1. VLAN 구성

**VLAN 20 (DMZ)**:
```
1. Interfaces → Assignments → VLANs
   ├── Parent Interface: vtnet1 (LAN)
   ├── VLAN Tag: 20
   └── Description: DMZ_Network
   
2. Interfaces → Assignments
   └── vtnet1.20 추가
   
3. Interfaces → [VLAN20]
   ├── Enable: ☑
   ├── IPv4: Static
   └── IP: 172.16.20.1/24
   
4. Services → DHCP Server → [VLAN20]
   └── Disable (고정 IP 사용)
```

**VLAN 30 (내부망)**:
```
1. Interfaces → Assignments → VLANs
   ├── Parent Interface: vtnet1 (LAN)
   ├── VLAN Tag: 30
   └── Description: Internal_Network
   
2. Interfaces → Assignments
   └── vtnet1.30 추가
   
3. Interfaces → [VLAN30]
   ├── Enable: ☑
   ├── IPv4: Static
   └── IP: 172.16.30.1/24
   
4. Services → DHCP Server → [VLAN30]
   └── Disable (고정 IP 사용)
```

### 4-2. 방화벽 규칙

**DMZ → 내부망 (MySQL 연결)**:
```
Firewall → Rules → [VLAN20]

Rule 1: Allow MySQL
  ├── Action: Pass
  ├── Protocol: TCP
  ├── Source: VLAN20 address (172.16.20.0/24)
  ├── Destination: VLAN30 address (172.16.30.10-12)
  ├── Port: 3306
  └── Description: Allow MySQL from DMZ to Internal
```

**내부망 → DMZ (차단)**:
```
Firewall → Rules → [VLAN30]

Rule 1: Block DMZ
  ├── Action: Block
  ├── Protocol: Any
  ├── Source: VLAN30 address (172.16.30.0/24)
  ├── Destination: VLAN20 address (172.16.20.0/24)
  └── Description: Block Internal to DMZ
```

**DMZ → 외부 (애플리케이션 연결)**:
```
Firewall → Rules → [VLAN20]

Rule 2: Allow External MySQL
  ├── Action: Pass
  ├── Protocol: TCP
  ├── Source: Any (외부 애플리케이션)
  ├── Destination: VLAN20 address (172.16.20.20-26)
  ├── Port: 3306, 3307, 6033, 8404
  └── Description: Allow MySQL access from external
```

---

## 5. Terraform 설정

### 5-1. DMZ/내부망 변수

**terraform.tfvars**:
```hcl
# DMZ 설정
dmz_vlan_tag               = 20
dmz_ip_prefix              = "172.16.20"
dmz_gateway                = "172.16.20.1"

# 내부망 설정
internal_vlan_tag          = 30
internal_ip_prefix         = "172.16.30"
internal_gateway           = "172.16.30.1"

# HAProxy (DMZ)
haproxy_nodes              = 2
haproxy_ip_start           = 20  # 172.16.20.20-21

# ProxySQL (DMZ)
proxysql_nodes             = 2
proxysql_ip_start          = 25  # 172.16.20.25-26

# Percona (내부망)
percona_nodes              = 3
percona_ip_start           = 10  # 172.16.30.10-12
```

### 5-2. VM 배치

**Terraform이 하는 작업**:
```
1. HAProxy VM 생성
   ├── VLAN: 20 (DMZ)
   ├── IP: 172.16.20.20-21
   └── Gateway: 172.16.20.1
   
2. ProxySQL VM 생성
   ├── VLAN: 20 (DMZ)
   ├── IP: 172.16.20.25-26
   └── Gateway: 172.16.20.1
   
3. Percona VM 생성
   ├── VLAN: 30 (내부망)
   ├── IP: 172.16.30.10-12
   └── Gateway: 172.16.30.1
```

---

## 6. Ansible 설정

### 6-1. HAProxy 설정 (DMZ → 내부망)

**haproxy.cfg.j2**:
```
frontend mysql-read
    bind *:3306
    mode tcp
    default_backend mysql-read

backend mysql-read
    mode tcp
    balance roundrobin
    server pxc-1 172.16.30.10:3306 check
    server pxc-2 172.16.30.11:3306 check
    server pxc-3 172.16.30.12:3306 check
```

**작동 방식**:
```
외부 애플리케이션 → HAProxy (172.16.20.30:3306)
                → Internal Percona (172.16.30.10-12:3306)
```

### 6-2. ProxySQL 설정 (DMZ → 내부망)

**proxysql.cnf.j2**:
```
mysql_servers=
{
    {address: '172.16.30.10', hostgroup_id: 0},
    {address: '172.16.30.11', hostgroup_id: 0},
    {address: '172.16.30.12', hostgroup_id: 0}
}
```

**작동 방식**:
```
외부 애플리케이션 → ProxySQL (172.16.20.35:6033)
                → Internal Percona (172.16.30.10-12:3306)
```

### 6-3. Percona 설정 (내부망)

**my.cnf.j2**:
```
wsrep_cluster_address = gcomm://172.16.30.10,172.16.30.11,172.16.30.12
wsrep_node_address = 172.16.30.10
```

**Galera 복제**:
```
pxc-1 (172.16.30.10) ↔ pxc-2 (172.16.30.11) ↔ pxc-3 (172.16.30.12)
모든 통신이 내부망 (VLAN 30) 내에서만
```

---

## 7. 연결 방식

### 7-1. 애플리케이션 → HAProxy

**읽기 연결**:
```bash
mysql -h172.16.20.30 -P3306 -u app_user -p
# HAProxy VIP → Round-robin → Percona 노드 분산
```

**쓰기 연결**:
```bash
mysql -h172.16.20.30 -P3307 -u app_user -p
# HAProxy VIP → Least connections → 최적 Percona 노드
```

### 7-2. 애플리케이션 → ProxySQL

**쿼리 라우팅**:
```bash
mysql -h172.16.20.35 -P6033 -u app_user -p
# ProxySQL VIP → 쿼리 분석 → 읽기/쓰기 분리
# 읽기: 모든 노드 (172.16.30.10-12)
# 쓰기: 단일 writer (172.16.30.10)
```

### 7-3. HAProxy/ProxySQL → Percona

**HAProxy Backend**:
```
HAProxy (172.16.20.20) → Percona (172.16.30.10:3306)
                        → Percona (172.16.30.11:3306)
                        → Percona (172.16.30.12:3306)
```

**ProxySQL Backend**:
```
ProxySQL (172.16.20.25) → Percona (172.16.30.10:3306)
                         → Percona (172.16.30.11:3306)
                         → Percona (172.16.30.12:3306)
```

---

## 8. 보안 강화

### 8-1. DMZ 보안

**장점**:
- 외부 접근 포인트 분리
- 내부 데이터베이스 직접 접근 차단
- 공격 시 DMZ만 영향

**HAProxy/ProxySQL 보안**:
```
1. Stats Interface 보호
   ├── 강력한 비밀번호
   └── IP 제한
   
2. Connection Limits
   ├── max_connections 설정
   └── DoS 방지
   
3. TLS/SSL
   ├── MySQL TLS 연결
   └── 데이터 암호화
```

### 8-2. 내부망 보안

**장점**:
- 외부 직접 접근 불가
- HAProxy/ProxySQL만 접근
- 데이터 유출 방지

**Percona 보안**:
```
1. 내부망 격리
   ├── 외부 → Internal: Block
   └── DMZ → Internal: MySQL만 Allow
   
2. MySQL 사용자 권한
   ├── 애플리케이션 사용자: 제한 권한
   └── Root: HAProxy/ProxySQL에서만 접근
   
3. TLS
   ├── 클라이언트 TLS
   └── Galera TLS (노드 간 암호화)
```

---

## 9. IP 할당표

### DMZ (172.16.20.x)

| IP            | 용도            | 노드    | VLAN | 설명              |
|---------------|----------------|---------|------|-------------------|
| 172.16.20.1   | Gateway        | pfSense | 20   | VLAN 20 Gateway   |
| 172.16.20.20  | haproxy-1      | pve1    | 20   | HAProxy LB 1      |
| 172.16.20.21  | haproxy-2      | pve2    | 20   | HAProxy LB 2      |
| 172.16.20.25  | proxysql-1     | pve3    | 20   | ProxySQL 1        |
| 172.16.20.26  | proxysql-2     | pve4    | 20   | ProxySQL 2        |
| 172.16.20.30  | HAProxy VIP    | -       | 20   | HAProxy Virtual IP|
| 172.16.20.35  | ProxySQL VIP   | -       | 20   | ProxySQL Virtual IP|

### 내부망 (172.16.30.x)

| IP            | 용도            | 노드    | VLAN | 설명              |
|---------------|----------------|---------|------|-------------------|
| 172.16.30.1   | Gateway        | pfSense | 30   | VLAN 30 Gateway   |
| 172.16.30.10  | pxc-1          | pve1    | 30   | Bootstrap 노드    |
| 172.16.30.11  | pxc-2          | pve2    | 30   | Percona 노드 2    |
| 172.16.30.12  | pxc-3          | pve3    | 30   | Percona 노드 3    |

---

## 10. pfSense 방화벽 규칙 요약

| Source         | Destination    | VLAN    | Port    | Action | 설명                      |
|----------------|----------------|---------|---------|--------|---------------------------|
| Any            | DMZ (VLAN 20)  | 20      | 3306,3307,6033,8404 | Pass | 외부 → HAProxy/ProxySQL  |
| DMZ (VLAN 20)  | Internal (VLAN 30) | 20→30 | 3306    | Pass   | HAProxy/ProxySQL → Percona|
| Internal (VLAN 30) | DMZ (VLAN 20) | 30→20 | Any     | Block  | Percona → DMZ 차단        |
| Internal (VLAN 30) | Internal (VLAN 30) | 30 | 3306,4444,4567,4568 | Pass | Galera 복제              |
| Any            | Internal (VLAN 30) | - | Any     | Block  | 외부 → Percona 직접 차단  |

---

## 11. 배포 과정

### Step 1: pfSense VLAN 설정

```
1. VLAN 20 (DMZ) 생성
   ├── 172.16.20.1/24
   └── 방화벽 규칙 설정
   
2. VLAN 30 (내부망) 생성
   ├── 172.16.30.1/24
   └── 방화벽 규칙 설정
   
3. 방화벽 규칙 적용
   ├── DMZ → Internal: Allow MySQL
   └── Internal → DMZ: Block
```

### Step 2: Terraform 실행

```bash
cd terraform/environments/production

# terraform.tfvars 수정
vim terraform.tfvars
  ├── dmz_vlan_tag = 20
  ├── dmz_ip_prefix = "172.16.20"
  ├── internal_vlan_tag = 30
  └── internal_ip_prefix = "172.16.30"

terraform init
terraform plan
terraform apply
```

### Step 3: Ansible 실행

```bash
cd ansible

ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Ansible이 하는 작업:
# 1. HAProxy (DMZ): 내부망 Percona IP로 backend 설정
# 2. ProxySQL (DMZ): 내부망 Percona IP로 servers 설정
# 3. Percona (내부망): 내부망 IP로 Galera 설정
```

### Step 4: 연결 테스트

```bash
# HAProxy (DMZ VIP)
mysql -h172.16.20.30 -P3306 -u root -p

# ProxySQL (DMZ VIP)
mysql -h172.16.20.35 -P6033 -u app_user -p

# Percona 직접 (내부망) - pfSense에서 차단됨
mysql -h172.16.30.10 -u root -p  # → Connection refused (외부에서)
```

---

## 12. 모니터링

### DMZ 모니터링

**HAProxy Stats**: http://172.16.20.20:8404/stats
**ProxySQL Admin**: mysql -h172.16.20.25 -P6032 -uadmin -padmin

### 내부망 모니터링

**Percona**: 내부망에서만 접근 가능
```
pfSense에서 모니터링 서버 IP만 Allow
모니터링 서버 (172.16.30.50) → Percona (172.16.30.10-12)
```

---

## 13. 요약

**DMZ (172.16.20.x)**:
- 외부 접근 가능
- HAProxy, ProxySQL 배치
- 애플리케이션 연결 포인트

**내부망 (172.16.30.x)**:
- 외부 접근 불가
- Percona 데이터베이스 배치
- HAProxy/ProxySQL만 접근

**연결 흐름**:
```
외부 → DMZ (HAProxy/ProxySQL) → 내부망 (Percona)
```

**보안**:
- 내부망 직접 접근 차단
- DMZ만 외부 연결
- 방화벽 규칙으로 MySQL 포트만 허용