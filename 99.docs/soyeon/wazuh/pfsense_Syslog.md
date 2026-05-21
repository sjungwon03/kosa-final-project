# pfSense Syslog 설정  
다음은 Wazuh Agent를 설치할 수 없는 pfSense(최전방 방화벽)의 로그를 **514/UDP Syslog**로 원격 수집 설정 과정입니다.
> 최소 권한 원칙

---
## 01) pfSense에 Agent를 설치하지 않는 이유  
pfSense는 실시간 패킷을 처리하는 방화벽 장비입니다.  
외부 프로그램(Wazuh Agent)을 설치하면 커널 충돌이 발생할 수 있고,  
이는 방화벽 마비 → 네트워크 전체 장애로 이어질 수 있습니다.  
대신 pfSense가 기본 지원하는 **Syslog 원격 전송(514/UDP)** 으로 로그를 수집합니다.

> 방화벽이 뚫리더라도 내부 19대 서버 전부 Agent가 설치되어 있어 위협(이상)을 탐지할 수 있습니다.

---
## 02) 네트워크 구성 확인  
| 장비 | IP | 위치 |
|---|---|---|
| pfSense | 172.16.30.1 | VLAN30 게이트웨이 |
| siem-01 (Wazuh Manager) | 172.16.30.85 | VLAN30 내부망 |

pfSense가 siem-01(172.16.30.85)으로 Syslog를 전송할 때 목적지가 `172.16.30.x` 대역이므로 출발지 IP는 `172.16.30.1`입니다.  
따라서 Manager의 `allowed-ips`는 `172.16.30.1` 하나만 허용합니다.  

---
## 03-1) pfSense Syslog 설정 방법 (CLI)  
**1. pfSense 웹 콘솔 접속**
```
https://172.16.30.1
```

**2. Syslog 설정 메뉴 이동**
```
Status > System Logs > Settings
```

**3. Remote Logging Options 설정**

| 항목 | 값 |
|---|---|
| Enable Remote Logging | ✔ 체크 |
| Remote log servers IP | 172.16.30.85 |
| Remote log servers Port | 514 |
| Protocol | UDP |

**4. Remote Syslog Contents 항목 체크**

| 항목 | 수집 목적 |
|---|---|
| ✔ Firewall Events | 방화벽 차단·허용 로그 |
| ✔ General Authentication Events | 인증 로그 |
| ✔ DHCP Events | IP 할당 로그 |
| ✔ VPN Events | VPN 접속 로그 |

**5. Save 클릭**

---
## 03-2) pfSense Syslog 설정 방법 (UI)  
**1. pfSense 접속 후 쉘 진입**  
pfSense 메인 메뉴에서 `8` 입력 → 쉘(Shell) 진입

```
Enter an option: 8
```

**2. 원격 Syslog 설정 주입**

```bash
# Wazuh Manager IP(172.16.30.85)로 모든 로그를 전송하도록 설정
# config.xml에 원격 Syslog 서버 IP와 포트 주입
/usr/local/sbin/fcgicli -f /etc/inc/config.inc -d "config[syslog][remoteserver]=172.16.30.85"
/usr/local/sbin/fcgicli -f /etc/inc/config.inc -d "config[syslog][remoteserver2]="
/usr/local/sbin/fcgicli -f /etc/inc/config.inc -d "config[syslog][remoteport]=514"

# 모든 로그(방화벽, 시스템 등)를 원격으로 전송하도록 활성화
/usr/local/sbin/fcgicli -f /etc/inc/config.inc -d "config[syslog][sourceip]=any"
/usr/local/sbin/fcgicli -f /etc/inc/config.inc -d "config[syslog][enable]=yes"
/usr/local/sbin/fcgicli -f /etc/inc/config.inc -d "config[syslog][logallremote]=yes"

# 변경된 설정 파일 저장 및 캐시 삭제
rm /tmp/config.cache

# syslogd 서비스 재시작
/etc/rc.d/syslogd restart
```

**3. siem-01 ossec.conf 수신 설정 확인**  
쉘 스크립트 `02_manager_json_process.sh` 실행 시 자동으로 설정됩니다.  
아래 내용이 `/var/ossec/etc/ossec.conf`에 있는지 확인해주세요.

```xml
<remote>
  <connection>syslog</connection>
  <port>514</port>
  <protocol>udp</protocol>
  <allowed-ips>172.16.30.1</allowed-ips>
</remote>
```

확인 명령어:
```bash
grep -A 6 "syslog" /var/ossec/etc/ossec.conf
```

---
## 04) 수신 확인 (siem-01에서)

```bash
# pfSense Syslog 수신 여부 실시간 확인
sudo tcpdump -i any udp port 514
```
이렇게 pfSense 로그가 출력되면 정상입니다.
