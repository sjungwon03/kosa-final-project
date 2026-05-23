# Wazuh Manager 재시작 실패 트러블슈팅
## 증상
<img width="800" alt="image" src="https://github.com/user-attachments/assets/9d98bab8-64a1-44d7-b8ac-c96504d9425b" />


## 원인 분석
### 1단계 - 로그 확인
```bash
sudo journalctl -u wazuh-manager -n 15 --no-pager
```

```
wazuh-analysisd: ERROR: (1226): Error reading XML file 'etc/rules/pfsense_rules.xml': 
  XMLERR: Bad attribute closing for 'encoding'='UTF-8'. (line 1).
wazuh-analysisd: CRITICAL: (1220): Error loading the rules: 'etc/rules/pfsense_rules.xml'.
```

### 2단계 - 원인 파악
Wazuh 4.14.5에 pfSense 룰/디코더가 이미 내장되어 있음을 확인
<img width="800" alt="image" src="https://github.com/user-attachments/assets/81096739-ce46-4290-a8e9-d1ad9a210aea" />
```bash
sudo find /var/ossec -name "*.xml" | xargs sudo grep -l "pfsense" 2>/dev/null

/var/ossec/etc/decoders/pfsense_decoders.xml              ← 수동 생성 (충돌)
/var/ossec/etc/rules/pfsense_rules.xml                    ← 수동 생성 (충돌)
/var/ossec/ruleset/decoders/0455-pfsense_decoders.xml     ← 이미 내장되어 있음
/var/ossec/ruleset/rules/0540-pfsense_rules.xml           ← 이미 내장되어 있음
```

**원인**: 02-manager_json_process.sh에서 생성한 커스텀 pfSense 룰/디코더 파일이 Wazuh 내장 파일과 중복되어 충돌 발생.  
또한 `tee` heredoc 방식으로 생성 시 XML 인코딩 헤더가 손상됨.

## 해결&결과
수동 생성한 파일 삭제 (내장 파일 사용):
<img width="800" alt="image" src="https://github.com/user-attachments/assets/9de35386-84ca-46af-97bc-e2d5fa8f58f9" />

```bash
sudo rm /var/ossec/etc/rules/pfsense_rules.xml
sudo rm /var/ossec/etc/decoders/pfsense_decoders.xml
sudo systemctl restart wazuh-manager
sudo systemctl status wazuh-manager --no-pager | grep Active
     Active: active (running) since #날짜...
```

## 재발 방지
1) `02-manager_json_process.sh`의 pfSense 디코더/룰 생성 함수 제거  
2) Wazuh 4.x는 `/var/ossec/ruleset/` 하위에 pfSense 룰/디코더를 기본 내장하므로 별도 생성 불필요.
