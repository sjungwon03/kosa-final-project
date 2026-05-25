# Wazuh 트러블슈팅
## ① Wazuh 서비스 구동 실패 (Timeout / 좀비 프로세스)

**원인**
systemd 제한 시간 초과 또는 강제 종료 후 잔재 프로세스가 포트를 점유.

**해결**
잔재 프로세스 소거 후 실패 이력 초기화 및 순차 재가동.
```bash
# 프로세스 강제 종료
sudo pkill -9 -f wazuh-indexer
sudo pkill -9 -f wazuh-manager
sudo pkill -9 -f wazuh-dashboard

# 실패 기록 리셋 및 순차 재시작 (Indexer → Manager → Dashboard 순서 필수)
sudo systemctl reset-failed wazuh-indexer  && sudo systemctl start wazuh-indexer  && sleep 5
sudo systemctl reset-failed wazuh-manager  && sudo systemctl start wazuh-manager  && sleep 5
sudo systemctl reset-failed wazuh-dashboard && sudo systemctl start wazuh-dashboard && sleep 5

# 상태 확인
sudo systemctl status wazuh-indexer wazuh-manager wazuh-dashboard --no-pager | grep Active
```

## ② Wazuh Manager 버전 불일치 (Agent 등록 실패)
**원인**
Ansible 설치 시 Manager v4.7.5, Agent v4.14.5로 버전 불일치 → Agent 등록 거부.

**해결**
Manager를 Agent 버전에 맞게 업그레이드.
```bash
sudo apt install wazuh-manager=4.14.5-*
sudo systemctl restart wazuh-manager
```

## ③ Wazuh Indexer 인증서 IP 불일치 (x509 오류)
**원인**  
Ansible 설치 시 인증서가 자동으로 `127.0.0.1`로 발급되어 `172.16.30.85` 접근 시 거부.

**해결**  
`ssl.verification_mode: none`으로 SSL 검증 우회 (내부망 환경).  
`filebeat.yml`의 `output.elasticsearch` 블록에 아래 설정 추가:
```yaml
ssl.verification_mode: none
```

## ④ Wazuh Indexer 9200 포트 외부 미수신
**원인**  
`network.host`가 `127.0.0.1`로 설정되어 외부 접근 불가.  

**해결**  
```bash
sudo sed -i 's/network.host: "127.0.0.1"/network.host: "0.0.0.0"/' /etc/wazuh-indexer/opensearch.yml
sudo systemctl restart wazuh-indexer
```

## ⑤ pfSense 커스텀 디코더/룰 XML 인코딩 오류

**증상**  
wazuh-manager 재시작 시 즉시 실패하며 analysisd가 pfsense_rules.xml을 읽지 못하고 중단됨.  
<img width="710" alt="image" src="https://github.com/user-attachments/assets/9d98bab8-64a1-44d7-b8ac-c96504d9425b" />

**원인**  
Wazuh 4.x에 pfSense 룰/디코더가 이미 내장되어 있음에도 수동으로 생성한 커스텀 파일이 충돌.
```bash
sudo find /var/ossec -name "*.xml" | xargs sudo grep -l "pfsense" 2>/dev/null

/var/ossec/etc/decoders/pfsense_decoders.xml          ← 수동 생성 (충돌)
/var/ossec/etc/rules/pfsense_rules.xml                ← 수동 생성 (충돌)
/var/ossec/ruleset/decoders/0455-pfsense_decoders.xml ← 이미 내장
/var/ossec/ruleset/rules/0540-pfsense_rules.xml       ← 이미 내장
```
> 이때 `tee` heredoc 방식으로 생성하면 XML 인코딩 헤더가 손상될 수 있어 주의해야 함.

**해결**  
수동 생성한 파일을 삭제하고 내장 파일을 사용.  
<img width="600" alt="image" src="https://github.com/user-attachments/assets/9de35386-84ca-46af-97bc-e2d5fa8f58f9" />  
> Wazuh 4.x 내장 경로:
> `/var/ossec/ruleset/rules/0540-pfsense_rules.xml`         # 룰(탐지조건)  
> `/var/ossec/ruleset/decoders/0455-pfsense_decoders.xml`   # 디코더(로그 파싱)


## ⑥ Filebeat 실행 실패 (pthread_create: Operation not permitted)
**원인**  
seccomp(보안 컴퓨팅 모드)가 스레드 생성을 차단.

**해결**  
systemd override로 SecureBits 제한 해제.  
<img width="600" alt="filebeat_정상실행" src="https://github.com/user-attachments/assets/beaa5dfb-e486-4881-9aa1-fa364b9023d5" />

## ⑦ ossec.conf XML 구조 오류 (active-response / global 블록 중복)
**원인**  
`sed -i "/<\/ossec_config>/r"` 방식으로 블록 삽입 시 `</ossec_config>` 밖에 삽입되거나 중복 삽입 발생.

**해결**  
구조 확인 후 중복 블록을 수동으로 제거.
```bash
# ossec.conf 구조 확인
sudo grep -n "ossec_config\|global\|remote\|active-response" /var/ossec/etc/ossec.conf
```

---
## ⑧ 재발 방지
1. `02-manager_json_process.sh`의 pfSense 디코더/룰 생성 함수 제거 — Wazuh 4.x는 `/var/ossec/ruleset/` 하위에 pfSense 룰/디코더를 기본 내장하므로 별도 생성 불필요.  
2. ossec.conf 블록 삽입은 `sed` 대신 Python 또는 수동 작성으로 처리해 XML 구조 오류 방지.  
3. Wazuh 컴포넌트 재시작 시 반드시 Indexer → Manager → Dashboard 순서 준수.  
4. Ansible으로 설치 시 Manager와 Agent 버전 일치 여부 사전 확인.  
5. 내부망 환경에서 Indexer 인증서 발급 IP와 실제 접속 IP 일치 여부 확인, 불일치 시 `ssl.verification_mode: none` 적용.
