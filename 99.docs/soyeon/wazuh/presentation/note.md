# 발표 보충 노트
## Wazuh 보안 정책 구성 및 자동화

---
## ②.⑤ Active Response 설정이란?
공격이 탐지되었을 때 **어떤 서버에서, 얼마나 차단할지**에 관한 정책을 Manager 서버에 주입하는 설정입니다.  
`ossec.conf` 파일에 작성해 적용합니다.  

**기본 설정 예시 (XML)**
```xml
<active-response>
  <command>firewall-drop</command>  <!-- 차단 방식: iptables로 IP 차단 -->
  <location>local</location>        <!-- 차단 범위: 해당 서버만 -->
  <rules_id>5720</rules_id>         <!-- 트리거 룰: SSH 브루트포스 -->
  <timeout>600</timeout>            <!-- 자동 해제: 10분 후 -->
</active-response>
```

**05-active_response.sh에 설정한 차단 정책 (총 4개)**
| 룰 ID | 탐지 조건 | 차단 범위 | 자동 해제 |
|---|---|---|---|
| 5720 | SSH 브루트포스 | 해당 서버만 | 10분 |
| 5763 | SSH 인증 반복 실패 | 해당 서버만 | 10분 |
| 100201 | pfSense 포트스캔 | 전체 10대 | 30분 |
| 100211 | pfSense OpenVPN 브루트포스 | 전체 10대 | 30분 |

---
## ③ Manager가 룰로 분석하고 JSON 경고문을 생성하는 과정
Wazuh 설치 시 내장된 룰과 Agent로부터 들어온 로그를 비교한 뒤,  
위협이 탐지되면 `05-active_response.sh`에 미리 주입해둔 차단 정책에 따라 자동으로 공격 IP를 차단합니다.

---
## ③ API 감사 로그란?
Kubernetes는 컨테이너 로그와 API 감사 로그 두 가지를 추가로 수집합니다.  
API 감사 로그는 **누가 어떤 권한으로 클러스터에 접근했는지**를 기록하는 로그입니다.

---
## ③ Filebeat란? (로그 전달 도구)
위협으로 판단된 이벤트는 JSON 형식으로 `alerts.json` 파일에 기록됩니다.  
이를 Indexer(OpenSearch)로 전달하기 위한 도구가 필요한데, 그 역할을 하는 것이 **Filebeat**입니다.
```
alerts.json → Filebeat → Wazuh Indexer (OpenSearch)
```

---
## ⑤ Brute Force(무차별 대입) 공격이란?
비밀번호를 맞출 때까지 수천, 수만 번 반복해서 시도하는 공격입니다.

**OpenVPN Brute Force**도 같은 원리로, VPN 계정 비밀번호를 무차별로 대입해 VPN에 침입하려는 공격입니다.
VPN이 뚫리면 내부망 전체에 접근 가능해지기 때문에 매우 위험합니다.
