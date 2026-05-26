# pfSense 문제 해결 (초보자용)

작성자: hyeyun

---

## VLAN 문제

### VLAN 인터페이스가 보이지 않음

**원인**: Parent interface 이름 불일치

**해결**:

```
1. Interfaces → Assignments → VLANs
2. Parent interface 이름 확인
   - vmx0, igb0, enp0s3 등

3. pfSense shell에서 확인:
   ifconfig -a | grep -i vlan

4. Proxmox VLAN bridge 확인:
   vmbr1 → VLAN aware: ☑
   VLAN IDs: 10 20 30 40
```

### VLAN 간 통신 안됨

**원인**: 방화벽 규칙 없음

**해결**:

```
1. Firewall → Rules → [Interface]
2. Pass rule 추가

2. Diagnostics → Ping
3. VLAN gateway ping 테스트
   ping 172.16.30.1
```

---

## 방화벽 문제

### Traffic이 차단됨

**원인**: Rule 없음 또는 순서 오류

**해결**:

```
1. Status → System Logs → Firewall
2. Blocked traffic 확인
   - Source IP
   - Destination IP
   - Port

3. Firewall → Rules → [Interface]
4. Pass rule 추가

5. 규칙 순서 확인 (Pass가 Block 위에)
```

### Alias 적용 안됨

**원인**: Alias 내용 오류

**해결**:

```
1. Firewall → Aliases
2. Alias 내용 확인
   - IP: 172.16.30.10 (CIDR 없이)
   - Port: 3306 (범위 없이)

3. Apply Changes
```

---

## NAT 문제

### Port Forward 작동 안됨

**원인**: NAT rule 또는 Firewall rule 없음

**해결**:

```
1. Firewall → NAT → Port Forward
2. NAT rule 확인
   - Internal IP 정확한지
   - Internal Port 정확한지

3. Firewall → Rules → WAN
4. Port Forward용 Pass rule 추가

4. Internal service 확인
   ssh 172.16.30.x
   curl localhost:80
```

### 외부 접속 실패

**원인**: Service가 실행 안됨

**해결**:

```bash
# Internal service 확인
kubectl get pods -n devops
kubectl get svc -n devops

# Service IP 확인
kubectl get svc argocd-server -n devops
```

---

## Service 접근 문제

### Percona 접근 안됨

**원인**: 방화벽 rule 또는 MySQL service

**해결**:

```
1. Firewall → Rules → DMZ
2. DMZ → Percona Pass rule 확인

2. Percona VM에서:
   systemctl status mysql
   mysql -h localhost -P3306

3. DMZ에서 테스트:
   ssh kosa@172.16.20.20
   mysql -h172.16.30.10 -P3306
```

### Kubernetes 접근 안됨

**원인**: K8s API 접근 차단

**해결**:

```
1. Firewall → Rules → INTERNAL
2. K8s Port (6443) Pass rule 확인

2. K8s cluster에서:
   kubectl get nodes
   kubectl cluster-info

3. API 테스트:
   curl -k https://172.16.30.21:6443
```

---

## Diagnostic Tools

### Ping 테스트

```
1. Diagnostics → Ping

Host: 172.16.30.10
Count: 4
Interface: INTERNAL

→ Start Ping
```

### Traceroute

```
1. Diagnostics → Traceroute

Host: 172.16.30.10
Interface: INTERNAL

→ Start Traceroute
```

### Port Lookup

```
1. Diagnostics → Port Lookup

Port: 3306
Protocol: TCP

→ Lookup
```

### Packet Capture

```
1. Diagnostics → Packet Capture

Interface: INTERNAL
Protocol: TCP
Port: 3306

→ Start Capture
→ 패킷 확인
```

---

## Log 확인

### Firewall Log

```
1. Status → System Logs → Firewall
2. Normal View

Filter:
  - Interface: DMZ
  - Action: Block

Blocked traffic 확인
```

### System Log

```
1. Status → System Logs → General
2. System events 확인
```

---

## Config Backup

### 백업

```
1. Diagnostics → Backup & Restore
2. Download Configuration as XML
3. 백업 파일 저장
```

### 복원

```
1. Diagnostics → Backup & Restore
2. Restore Configuration
3. 백업 파일 선택
4. Restore
```

---

## Factory Reset

```
Console에서:

1) pfSense shell 선택
2) /etc/rc.initial.firmware_update
3) Reset to factory defaults 선택

# 모든 설정 삭제됨!
```

---

## 참고 링크

1. **pfSense 문제 해결**: https://docs.pfsense.org/index.php/Troubleshooting