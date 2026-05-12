# Percona XtraDB Cluster 아키텍처

## 개요

VM 기반 Percona XtraDB Cluster 구성으로 Proxmox HA 설정 포함

---

## 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                        DMZ VLAN 20 (172.16.20.0/24)             │
│                        Gateway: 172.16.20.1                     │
│                   (외부 접근 가능, HAProxy/ProxySQL 배치)        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         pfSense Firewall                        │
│                    VLAN 라우팅 및 방화벽 규칙                    │
│     DMZ(VLAN20) → Internal(VLAN30): Allow MySQL (3306)          │
│     Internal(VLAN30) → DMZ(VLAN20): Block                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      HAProxy 로드밸런서 (DMZ)                   │
│                   VIP: 172.16.20.30                             │
│         ┌──────────────────────────────────────────┐            │
│         │ haproxy-1 (172.16.20.20) - kosa21          │            │
│         │ haproxy-2 (172.16.20.21) - kosa22          │            │
│         └──────────────────────────────────────────┘            │
│                  Port 3306 (Read) / 3307 (Write)                │
│           Stats Interface: Port 8404                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      ProxySQL Layer (DMZ)                       │
│                   VIP: 172.16.20.35                             │
│         ┌──────────────────────────────────────────┐            │
│         │ proxysql-1 (172.16.20.25) - kosa23         │            │
│         │ proxysql-2 (172.16.20.26) - kosa24         │            │
│         └──────────────────────────────────────────┘            │
│         Admin Interface: Port 6032                              │
│         MySQL Proxy: Port 6033                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Internal VLAN 30 (172.16.30.0/24)            │
│                        Gateway: 172.16.30.1                     │
│                   (외부 접근 불가, Percona 배치)                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                Percona XtraDB Cluster (3 Nodes)                 │
│                   (Internal VLAN 30)                             │
│         ┌──────────────────────────────────────────┐            │
│         │ pxc-1 (172.16.30.10) - kosa21 [Bootstrap]  │            │
│         │ pxc-2 (172.16.30.11) - kosa22              │            │
│         │ pxc-3 (172.16.30.12) - kosa23              │            │
│         └──────────────────────────────────────────┘            │
│                    Galera Cluster Replication                   │
│                        Port 3306                                 │
│         SST Port: 4444, IST: 4568, Galera: 4567                │
└─────────────────────────────────────────────────────────────────┘
```
┌─────────────────────────────────────────────────────────────────┐
│                        VLAN 30 (172.16.30.0/24)                 │
│                        Gateway: 172.16.30.1                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         pfSense Firewall                        │
│                    VLAN Routing & Firewall Rules                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      HAProxy Load Balancer                      │
│                   (DMZ VLAN 20)                                  │
│         ┌──────────────────────────────────────────┐            │
│         │ haproxy-1 (172.16.20.20) - kosa21          │            │
│         │ haproxy-2 (172.16.20.21) - kosa22          │            │
│         └──────────────────────────────────────────┘            │
│                  Port 3306 (Read) / 3307 (Write)                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      ProxySQL Layer                             │
│                   (DMZ VLAN 20)                                  │
│         ┌──────────────────────────────────────────┐            │
│         │ proxysql-1 (172.16.20.25) - kosa23         │            │
│         │ proxysql-2 (172.16.20.26) - kosa24         │            │
│         └──────────────────────────────────────────┘            │
│                    Port 6033 (MySQL Proxy)                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                Percona XtraDB Cluster (3 Nodes)                 │
│                   (Internal VLAN 30)                             │
│         ┌──────────────────────────────────────────┐            │
│         │ pxc-1 (172.16.30.10) - kosa21 [Bootstrap]  │            │
│         │ pxc-2 (172.16.30.11) - kosa22              │            │
│         │ pxc-3 (172.16.30.12) - kosa23              │            │
│         └──────────────────────────────────────────┘            │
│                    Galera Cluster Replication                   │
│                        Port 3306                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 구성 요소 상세

### 1. Proxmox 클러스터 (4 Nodes)

**노드**: kosa21, kosa22, kosa23, kosa24

**기능**:
- HA Group: `percona-ha`
- VM 분산: 노드 간 라운드 로빈 배치
- VM 마이그레이션: 노드 장애 시 자동 마이그레이션
- 리소스 모니터링: Proxmox HA 내장 기능

### 2. Percona XtraDB Cluster Nodes (3 VMs)

**VM 사양** (Percona 최소 요구사항):
- CPU: 2 cores
- Memory: 4GB (Percona 최소 2GB 권장)
- Disk: 60GB (Percona 최소 60GB 권장)
- Network: VLAN 30, VirtIO 드라이버

**노드 분산**:
- pxc-1: kosa21 (Bootstrap 노드)
- pxc-2: kosa22
- pxc-3: kosa23

**기술 스택**:
- Percona XtraDB Cluster 8.0
- Galera Replication Library
- wsrep (Write Set REPlication)

### 3. HAProxy 로드밸런서 (2 VMs)

**VM 사양**:
- CPU: 2 cores
- Memory: 2GB
- Disk: 20GB
- Network: VLAN 20 (DMZ), VirtIO 드라이버

**노드 분산**:
- haproxy-1: kosa21
- haproxy-2: kosa22

**로드밸런싱 구성**:
- Port 3306: 읽기 쿼리 (Round Robin)
- Port 3307: 쓰기 쿼리 (Least Connections)
- Stats Interface: Port 8404
- Health Checks: TCP-level MySQL 포트 체크

### 4. ProxySQL Nodes (2 VMs)

**VM 사양**:
- CPU: 2 cores
- Memory: 4GB
- Disk: 30GB
- Network: VLAN 20 (DMZ), VirtIO 드라이버

**노드 분산**:
- proxysql-1: kosa23
- proxysql-2: kosa24

**기능**:
- 쿼리 라우팅
- 커넥션 풀링
- 쿼리 캐싱
- 읽기/쓰기 분리
- Admin Interface: Port 6032
- MySQL Proxy Port: Port 6033

---

## 네트워크 구성

### VLAN 20 - DMZ Network (외부 접근 가능)

**IP 할당**:
```
172.16.20.1    - Gateway (pfSense VLAN 20)
172.16.20.2-19 - Reserved
172.16.20.20   - haproxy-1
172.16.20.21   - haproxy-2
172.16.20.25   - proxysql-1
172.16.20.26   - proxysql-2
172.16.20.30   - HAProxy VIP
172.16.20.35   - ProxySQL VIP
```

### VLAN 30 - Internal Network (외부 접근 불가)

**IP 할당**:
```
172.16.30.1    - Gateway (pfSense VLAN 30)
172.16.20.2-9  - Reserved
172.16.30.10   - pxc-1 (Bootstrap)
172.16.30.11   - pxc-2
172.16.30.12   - pxc-3
```

### pfSense 설정 필요

**VLAN 30 인터페이스**:
- Interface: vtnet1.30 (또는 물리적 NIC VLAN)
- IPv4: 172.16.30.1/24
- DHCP: 옵션 (고정 IP 사용 시 비활성화)

**방화벽 규칙**:
```
VLAN 30 → Any: Pass (데이터베이스 트래픽 허용)
VLAN 30 → VLAN 10/20/30: Block (필요시 격리)
```

---

## HA 설정

### Proxmox HA Groups

**HA Group**: `percona-ha`

**설정**:
```bash
# HA 그룹 생성
ha-manager add-group percona-ha --nodes kosa21,kosa22,kosa23,kosa24 --restricted 1

# VM을 HA에 추가
ha-manager add vmid:100 --group percona-ha --state started
ha-manager add vmid:101 --group percona-ha --state started
```

**HA 설정값**:
- `max_relocate`: 2 (최대 마이그레이션 수)
- `max_restart`: 2 (최대 재시작 수)
- `state`: started (VM 실행 상태)

### HA 동작 방식

**노드 장애 시나리오**:
1. Proxmox가 노드 장애 감지
2. HA manager가 장애 노드의 VM을 마이그레이션
3. VM이 사용 가능한 노드로 이동
4. Percona 클러스터 자동 재구성
5. Galera 복제가 나머지 노드에서 계속 진행

**복구 시나리오**:
1. 장애 노드 복구
2. VM을 다시 마이그레이션 (수동 또는 자동)
3. Percona 노드가 SST로 클러스터에 재가입
4. 전체 클러스터 동기화 복원

---

## 배포 워크플로우

### Step 1: Terraform - 인프라 프로비저닝

```bash
cd terraform/environments/production

# Terraform 초기화
terraform init

# 배포 계획 확인
terraform plan

# 구성 적용
terraform apply
```

**Terraform 생성 내용**:
- 3개 Percona VM
- 2개 HAProxy VM
- 2개 ProxySQL VM
- HA 그룹 설정
- Ansible 인벤토리 파일

### Step 2: Ansible - 소프트웨어 구성

```bash
cd ansible

# 메인 플레이북 실행
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# 클러스터 상태 확인
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

**Ansible 구성 내용**:
- 모든 노드에 공통 패키지 설치
- Percona XtraDB Cluster (부트스트랩 + 가입)
- HAProxy 로드밸런싱 규칙
- ProxySQL 쿼리 라우팅

### Step 3: 배포 후 검증

**Percona 클러스터 확인**:
```bash
# Percona 노드에서 실행
mysql -e "SHOW STATUS LIKE 'wsrep_%'"

# 예상 출력:
# wsrep_cluster_size: 3
# wsrep_cluster_status: Primary
# wsrep_local_state_comment: Synced
```

**HAProxy 확인**:
```bash
# Stats 인터페이스 접속
http://172.16.20.20:8404/stats
http://172.16.20.21:8404/stats
```

**ProxySQL 확인**:
```bash
# Admin 연결
mysql -h172.16.20.25 -P6032 -uadmin -padmin

# 서버 확인
SELECT * FROM mysql_servers;

# 사용자 확인
SELECT * FROM mysql_users;
```

---

## 연결 예시

### MySQL 직접 연결 (HAProxy 경유)

**읽기 연결 (Port 3306)**:
```bash
mysql -h172.16.30.30 -P3306 -u root -p
# 모든 Percona 노드로 Round-robin 로드밸런싱
```

**쓰기 연결 (Port 3307)**:
```bash
mysql -h172.16.30.30 -P3307 -u root -p
# 최적 쓰기 노드로 Least connection
```

### ProxySQL 연결

**MySQL Proxy (Port 6033)**:
```bash
mysql -h172.16.30.35 -P6033 -u app_user -p
# 규칙 기반 쿼리 라우팅
# 읽기 쿼리 → Hostgroup 10 (모든 노드)
# 쓰기 쿼리 → Hostgroup 0 (단일 writer)
```

**Admin Interface (Port 6032)**:
```bash
mysql -h172.16.20.25 -P6032 -u admin -padmin
# 구성 관리
# 쿼리 통계
# 커넥션 모니터링
```

---

## 운영 관리

### 새 Percona 노드 추가

1. **Terraform**: 구성에 노드 추가
```hcl
percona_nodes = 4  # 3에서 4로 증가
```

2. **Terraform 적용**:
```bash
terraform apply
```

3. **Ansible**: 새 노드 구성
```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit pxc-4
```

4. **클러스터 자동 동기화**: 새 노드가 SST(State Snapshot Transfer)로 가입

### Percona 클러스터 복구

**처음부터 부트스트랩**:
```bash
# 모든 MySQL 노드 중지
ansible -i inventory/hosts.ini percona -m systemd -a "name=mysql state=stopped"

# 첫 번째 노드 부트스트랩
ansible-playbook playbooks/recover.yml -e "pxc_bootstrap=true"
```

**클러스터 상태 확인**:
```bash
# 노드에서 실행
mysql -e "SELECT VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME='wsrep_local_state_comment'"
```

### HAProxy 관리

**백엔드 서버 추가**:
```bash
# Ansible 인벤토리 수정
# 새 Percona 노드 IP 추가

# HAProxy 재구성
ansible-playbook playbooks/site.yml --limit haproxy
```

**서버 Drain**:
```bash
# HAProxy stats 인터페이스에서
# 서버 상태를 "DRAIN"으로 설정
```

### ProxySQL 관리

**MySQL 서버 추가**:
```bash
# ProxySQL admin에서 실행
mysql -h127.0.0.1 -P6032 -uadmin -padmin

INSERT INTO mysql_servers (hostgroup_id, hostname, port) VALUES (0, '172.16.30.13', 3306);
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
```

**쿼리 규칙 추가**:
```bash
INSERT INTO mysql_query_rules (rule_id, match_pattern, destination_hostgroup) VALUES (1, '^SELECT', 10);
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```

---

## 모니터링

### Percona 모니터링

**클러스터 메트릭**:
- `wsrep_cluster_size`: 노드 수
- `wsrep_cluster_status`: Primary/Non-Primary
- `wsrep_local_state_comment`: Synced/Donor/Joining
- `wsrep_flow_control_paused`: Flow control 상태
- `wsrep_cert_deps_distance`: Certification 거리

**성능 메트릭**:
- `wsrep_replicated`: 복제된 Bytes
- `wsrep_received`: 수신한 Bytes
- `wsrep_commit_ooe`: Out-of-order commits

### HAProxy 모니터링

**Stats Interface**: http://172.16.20.20:8404/stats

**주요 메트릭**:
- Backend status: UP/DOWN
- Sessions: Current/Total
- Bytes: In/Out
- Response time: Average/Max

### ProxySQL 모니터링

**Stats Tables**:
```sql
SELECT * FROM stats_mysql_connection_pool;
SELECT * FROM stats_mysql_query_digest;
SELECT * FROM stats_mysql_commands_counters;
```

---

## 보안 권장사항

### 네트워크 보안

1. **VLAN 격리**: 데이터베이스 네트워크와 애플리케이션 네트워크 분리
2. **방화벽 규칙**: 데이터베이스 포트 접근 제한
3. **Source IP 제한**: 특정 애플리케이션 IP만 허용

### MySQL 보안

1. **강력한 비밀번호**: 기본 비밀번호 즉시 변경
2. **제한된 사용자**: 권한이 제한된 애플리케이션 전용 사용자 생성
3. **SSL 연결**: 클라이언트 연결에 TLS 활성화

### HAProxy/ProxySQL 보안

1. **Stats 보호**: Stats 인터페이스에 강력한 비밀번호
2. **접근 제어**: Admin 인터페이스 IP 제한
3. **Connection 제한**: 적절한 connection limit 설정

---

## 문제 해결

### Percona 클러스터 문제

**Split-Brain**:
```
wsrep_cluster_status: Non-Primary
```
해결: 한 노드에서 `pc.bootstrap=YES`로 부트스트랩

**노드 가입 실패**:
```
wsrep_local_state_comment: Joining
```
확인: SST 프로세스, 네트워크 연결, 방화벽 규칙

**복제 지연**:
```
wsrep_flow_control_paused: > 0.0
```
확인: 노드 성능, 네트워크 대역폭, 쿼리 최적화

### HAProxy 문제

**Backend Down**:
- MySQL 프로세스 상태 확인
- 네트워크 연결 확인
- HAProxy health check 설정 확인

**Connection Refused**:
- HAProxy 포트 바인딩 확인
- 방화벽 규칙 확인
- 백엔드 서버 상태 확인

### ProxySQL 문제

**쿼리 라우팅 작동 안 함**:
- 쿼리 규칙 설정 확인
- Hostgroup 할당 확인
- `mysql_query_rules_fast_routing`으로 테스트

**Connection Pool 소진**:
- `max_connections` 증가
- 애플리케이션 커넥션 관리 확인
- `stats_mysql_connection_pool` 모니터링

---

## 리소스 요구사항 요약

| 구성 요소 | CPU | Memory | Disk | 수량 | 총 리소스 |
|-----------|-----|--------|------|-------|-----------|
| Percona   | 2   | 4GB    | 60GB | 3     | 6 CPU, 12GB RAM, 180GB |
| HAProxy   | 2   | 2GB    | 20GB | 2     | 4 CPU, 4GB RAM, 40GB |
| ProxySQL  | 2   | 4GB    | 30GB | 2     | 4 CPU, 8GB RAM, 60GB |
| **Total** |     |        |      | 7     | 14 CPU, 24GB RAM, 280GB |

---

## 다음 단계

1. **변수 수정**: `terraform.tfvars`와 `group_vars/all.yml` 편집
2. **pfSense 구성**: VLAN 30과 방화벽 규칙 설정
3. **인프라 프로비저닝**: Terraform 실행
4. **소프트웨어 배포**: Ansible 실행
5. **클러스터 검증**: 모든 구성 요소 상태 확인
6. **애플리케이션 구성**: 로드밸런서 VIP로 연결
7. **모니터링 설정**: 모니터링 솔루션 구현 (Prometheus/Grafana)
8. **Failover 테스트**: 노드 장애 시뮬레이션 및 HA 동작 확인