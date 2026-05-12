# pfSense 방화벽 규칙 상세 설정 (초보자용)

작성자: hyeyun

---

## 이 가이드로 무엇을 설정할 수 있나요?

VLAN 간 트래픽 제어 규칙을 설정합니다.

**규칙 예시**:
- DMZ → 내부망: MySQL 접근 허용
- 공용망 → 내부망: 모든 접근 차단
- 관리망 → 모든 VLAN: 접근 허용

---

## Alias 생성 (IP/Port 그룹화)

여러 IP나 Port를 하나의 이름으로 그룹화합니다.

### Step 1: Percona_Nodes Alias

```
1. Firewall → Aliases → Add

Name: Percona_Nodes
Type: Host(s)

Content:
  - 172.16.30.10  Description: pxc-1
  - 172.16.30.11  Description: pxc-2
  - 172.16.30.12  Description: pxc-3

→ Save → Apply Changes
```

### Step 2: DB_Ports Alias

```
Name: DB_Ports
Type: Port(s)

Content:
  - 3306  Description: MySQL
  - 4444  Description: SST
  - 4567  Description: Galera
  - 4568  Description: IST

→ Save → Apply Changes
```

### Step 3: K8s_Cluster Alias

```
Name: K8s_Cluster
Type: Host(s)

Content:
  - 172.16.30.21  Description: kosa21
  - 172.16.30.22  Description: kosa22
  - 172.16.30.23  Description: kosa23
  - 172.16.30.24  Description: kosa24

→ Save → Apply Changes
```

### Step 4: Alias 확인

```
1. Firewall → Aliases
2. 모든 Alias 목록 확인
```

---

## VLAN 20 (DMZ) 방화벽 규칙

### Rule 1: DMZ → Percona (MySQL)

HAProxy/ProxySQL이 Percona DB에 접근.

```
1. Firewall → Rules → DMZ → Add

Action: Pass
Protocol: TCP
Source: DMZ net (172.16.20.0/24)
Destination: Percona_Nodes (Alias)
Port: DB_Ports (Alias)
Description: DMZ to Percona DB
→ Save → Apply Changes
```

### Rule 2: DMZ → Kubernetes API

ArgoCD/GitLab이 K8s API에 접근.

```
Action: Pass
Protocol: TCP
Source: DMZ net
Destination: K8s_Cluster (Alias)
Port: 6443
Description: DMZ to K8s API
→ Save → Apply Changes
```

### Rule 3: Block DMZ → 공용망

```
Action: Block
Protocol: Any
Source: DMZ net
Destination: PUBLIC net
Port: Any
Description: Block DMZ to public
→ Save → Apply Changes
```

---

## VLAN 30 (내부망) 방화벽 규칙

### Rule 1: 내부망 통신 허용

```
Action: Pass
Protocol: Any
Source: INTERNAL net (172.16.30.0/24)
Destination: INTERNAL net
Port: Any
Description: Internal communication
→ Save → Apply Changes
```

### Rule 2: Percona Cluster 통신

```
Action: Pass
Protocol: TCP
Source: Percona_Nodes
Destination: Percona_Nodes
Port: DB_Ports
Description: Percona cluster replication
→ Save → Apply Changes
```

### Rule 3: Kubernetes Cluster 통신

```
Action: Pass
Protocol: TCP
Source: K8s_Cluster
Destination: K8s_Cluster
Port: 6443, 10250, 30000-32767
Description: K8s cluster communication
→ Save → Apply Changes
```

### Rule 4: Block 내부망 → 공용망

```
Action: Block
Protocol: Any
Source: INTERNAL net
Destination: PUBLIC net
Port: Any
Description: Block internal to public
→ Save → Apply Changes
```

---

## VLAN 40 (관리망) 방화벽 규칙

### Rule 1: 관리망 전체 접근

```
Action: Pass
Protocol: Any
Source: MGMT net (192.168.40.0/24)
Destination: Any
Port: Any
Description: Management full access
→ Save → Apply Changes
```

### Rule 2: Proxmox Web UI 접근

```
Action: Pass
Protocol: TCP
Source: MGMT net
Destination: MGMT net
Port: 8006
Description: Proxmox Web UI
→ Save → Apply Changes
```

---

## 규칙 순서 확인

### 중요: 규칙은 위에서 아래로 적용

```
1. Firewall → Rules → DMZ

규칙 순서:
  1) Pass: DMZ → Percona (3306)
  2) Pass: DMZ → K8s API (6443)
  3) Block: DMZ → Public
  4) Block: DMZ → Management

→ Apply Changes
```

---

## 규칙 테스트

### DMZ → Percona 접근 테스트

```bash
# HAProxy VM에서
ssh kosa@172.16.20.20

# Percona 접근
mysql -h172.16.30.10 -P3306 -u root -p
# 성공: Pass rule 작동
```

### 공용망 → 내부망 차단 테스트

```bash
# 공용망 PC에서
ssh kosa@192.168.10.100

ping 172.16.30.10
# 실패: Block rule 작동
```

---

## 규칙 Log 확인

```
1. Status → System Logs → Firewall
2. Normal View

Filter:
  - Action: Block
  - Interface: DMZ

Blocked traffic 확인
```

---

## 문제 해결

### Traffic이 차단됨

```
확인:
1. Firewall → Rules → [Interface]
2. Rule 순서 확인
3. Pass rule이 Block rule 위에 있어야 함
4. Apply Changes
```

### Alias 적용 안됨

```
확인:
1. Firewall → Aliases
2. Alias 내용 확인
3. IP/Port 정확한지 확인
4. Apply Changes
```

---

## 방화벽 규칙 표

| Source    | Destination  | Port     | Action | Description           |
|-----------|--------------|----------|--------|-----------------------|
| DMZ       | Percona_Nodes| DB_Ports | Pass   | DMZ to DB             |
| DMZ       | K8s_Cluster  | 6443     | Pass   | DMZ to K8s API        |
| DMZ       | PUBLIC       | Any      | Block  | Block DMZ to public   |
| INTERNAL  | INTERNAL     | Any      | Pass   | Internal communication|
| INTERNAL  | PUBLIC       | Any      | Block  | Block internal to public|
| MGMT      | Any          | Any      | Pass   | Management full access|

---

## 다음 단계

1. NAT/Port Forward 설정 → 03-pfsense-nat-setup.md