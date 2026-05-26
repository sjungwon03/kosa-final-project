# pfSense NAT/Port Forward 설정 (초보자용)

작성자: hyeyun

---

## NAT가 무엇인가요?

NAT (Network Address Translation)은 외부에서 내부 서비스에 접근하게 합니다.

**Port Forwarding**:
- 외부 Port → 내부 IP/Port 연결
- 예: 외부 80 → 내부 ArgoCD (172.16.30.x:80)

---

## ArgoCD Port Forward 설정

### Step 1: ArgoCD Web UI 접근

외부에서 ArgoCD Web UI에 접근합니다.

```
1. Firewall → NAT → Port Forward → Add

Interface: WAN (또는 PUBLIC)
Protocol: TCP
External Port: 80
Internal IP: 172.16.30.x (K8s Ingress IP)
Internal Port: 80
Description: ArgoCD HTTP
→ Save → Apply Changes
```

### Step 2: HTTPS Port Forward

```
Interface: WAN
Protocol: TCP
External Port: 443
Internal IP: 172.16.30.x (K8s Ingress IP)
Internal Port: 443
Description: ArgoCD HTTPS
→ Save → Apply Changes
```

---

## GitLab Port Forward 설정

### Step 1: GitLab Web UI

```
Interface: WAN
Protocol: TCP
External Port: 8080
Internal IP: 172.16.30.x (GitLab Service)
Internal Port: 80
Description: GitLab HTTP
→ Save → Apply Changes
```

### Step 2: GitLab SSH

Git push를 위해 SSH Port Forward.

```
Interface: WAN
Protocol: TCP
External Port: 2222
Internal IP: 172.16.30.x (GitLab Service)
Internal Port: 22
Description: GitLab SSH
→ Save → Apply Changes
```

---

## Harbor Port Forward 설정

### Step 1: Harbor Web UI

```
Interface: WAN
Protocol: TCP
External Port: 8443
Internal IP: 172.16.30.x (Harbor Service)
Internal Port: 443
Description: Harbor HTTPS
→ Save → Apply Changes
```

### Step 2: Harbor Registry

Docker 이미지 push/pull용.

```
Interface: WAN
Protocol: TCP
External Port: 5000
Internal IP: 172.16.30.x (Harbor Registry)
Internal Port: 5000
Description: Harbor Registry
→ Save → Apply Changes
```

---

## HAProxy Port Forward 설정

### MySQL 접근

외부에서 MySQL에 접근 (DMZ VIP).

```
Interface: WAN
Protocol: TCP
External Port: 3306
Internal IP: 172.16.20.30 (HAProxy VIP)
Internal Port: 3306
Description: MySQL Read
→ Save → Apply Changes

Interface: WAN
Protocol: TCP
External Port: 3307
Internal IP: 172.16.20.30
Internal Port: 3307
Description: MySQL Write
→ Save → Apply Changes
```

---

## NAT 규칙 확인

### Port Forward 목록

```
1. Firewall → NAT → Port Forward
2. 모든 규칙 확인

규칙 예시:
  - WAN:80 → 172.16.30.x:80 (ArgoCD)
  - WAN:443 → 172.16.30.x:443 (GitLab)
  - WAN:3306 → 172.16.20.30:3306 (MySQL)
```

### NAT Table 확인

```bash
# pfSense shell에서
pfctl -sn
```

---

## Port Forward 테스트

### ArgoCD 접속 테스트

```bash
# 외부 PC에서
curl http://<WAN_IP>:80

# 또는 Browser
http://<WAN_IP>
```

### MySQL 접속 테스트

```bash
# 외부 PC에서
mysql -h<WAN_IP> -P3306 -u root -p
```

---

## Firewall Rules 추가

Port Forward 후 방화벽 규칙도 필요합니다.

### WAN → ArgoCD Rule

```
1. Firewall → Rules → WAN → Add

Action: Pass
Protocol: TCP
Source: Any
Destination: 172.16.30.x
Port: 80, 443
Description: WAN to ArgoCD
→ Save → Apply Changes
```

---

## 문제 해결

### Port Forward 작동 안됨

```
확인:
1. Firewall → NAT → Port Forward
2. Rule Enable 확인
3. Internal IP/Port 정확한지 확인
4. Firewall Rules에 Pass rule 있는지 확인
```

### 외부 접속 실패

```bash
# Internal 서비스 확인
curl http://172.16.30.x:80

# NAT Table 확인
pfctl -sn
```

---

## NAT 규칙 표

| Service    | External Port | Internal IP        | Internal Port |
|------------|---------------|--------------------|---------------|
| ArgoCD     | 80, 443       | 172.16.30.x        | 80, 443       |
| GitLab     | 8080          | 172.16.30.x        | 80            |
| GitLab SSH | 2222          | 172.16.30.x        | 22            |
| Harbor     | 8443          | 172.16.30.x        | 443           |
| MySQL      | 3306, 3307    | 172.16.20.30       | 3306, 3307    |

---

## 다음 단계

1. 문제 해결 → 04-pfsense-troubleshooting.md