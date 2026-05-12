# Packer

- VMID 9000 (`ubuntu-2404-base`) 템플릿을 클론하여 Ansible 관리용 템플릿 생성
- ISO 부팅 없이 cloud-init 기반 베이스 템플릿을 클론해서 구성하는 방식


**파이프라인**
- 00.scripts (9000 생성)
- 01.packer (9008 생성)
- 02.terraform (VM 프로비저닝)


**디렉토리 구성**
```bash
01.packer/
├── ubuntu-2404-common/                # Ubuntu 24.04 LTS
│   ├── packer-ubuntu-template.pkr.hcl
│   ├── ssh-credentials.pkrvars.hcl
│   └── http/
├── plugins.pkr.hcl                    # proxmox 플러그인 선언
└── credentials.pkr.hcl                # Proxmox API 접속 정보
```



## Ubuntu 24.04 LTS

**스펙**

| 항목 | 값 |
|---|---|
| VM ID | 9008 (기본값, `-var="template_vm_id=9009"` 로 변경 가능) |
| 이름 | ubuntu-2404-common-v1 |
| 클론 소스 | 9000 (ubuntu-2404-base) |
| CPU | 2 cores / host |
| 메모리 | 2048 MB |
| 디스크 | 10G (rbd-storage / Ceph rbd-team4) |
| 네트워크 | virtio / vmbr0 / VLAN 20 |
| Machine | q35 |
| OS Type | l26 (Linux 2.6+) |

**주요 템플릿 구성**

| 항목 | 내용 |
|---|---|
| cloud-init | rbd-storage에 드라이브 생성. `cloud_init=true`가 드라이브를 새로 생성하면서 9000 템플릿의 ciuser/cipassword/ipconfig0을 초기화하므로, post-processor에서 동일한 값을 재주입 (의도적 중복) |
| SSH 인증 | 빌드 완료 후 패스워드 인증 비활성화, 키 인증만 허용 |
| Ansible 키 | `ssh-credentials.pkrvars.hcl`의 `ansible_public_key` 자동 등록 |
| qemu-guest-agent | 활성화 (Proxmox 연동) |
| 스토리지 | Ceph rbd-storage (클론 소스와 동일 풀) |

**기본 설치 패키지**

| 패키지 | 출처 | 설명 |
|---|---|---|
| curl, wget, git, vim, net-tools | Ubuntu APT | 기본 유틸리티 |
| auditd | Ubuntu APT | Linux 보안 감사 데몬. 시스템 콜·파일 접근 이벤트 기록. 설치만, 활성화는 Ansible에서 처리 |
| promtail | Grafana APT | Grafana Loki 로그 수집 에이전트 설치, 활성화는 Ansible에서 처리 |
| wazuh-agent | Wazuh 4.x APT | SIEM/보안 모니터링 에이전트 설치, 활성화는 Ansible에서 처리 |

**기본 계정**
- username: `kosa`
- password: `kosa1004`
- sudo: NOPASSWD

**사전 조건**
- VMID 9000 (`ubuntu-2404-base`) 템플릿 존재 (`00.scripts/create-ubuntu-2404-base.sh` 실행)
- 빌드 서버 → Proxmox 호스트(192.168.34.4) root SSH 키 인증 설정 (post-processor `qm` 실행에 필요)
  ```bash
  ssh-copy-id root@192.168.34.4
  ```
- Proxmox API 토큰 발급 후 `credentials.pkr.hcl` 작성

---

**실행**
```bash
cd 01.packer

# 빌드 (기본 VMID 9008)
packer init ubuntu-2404-common/
packer build \
  -var-file="credentials.pkr.hcl" \
  -var-file="ubuntu-2404-common/ssh-credentials.pkrvars.hcl" \
  ubuntu-2404-common/

# VMID 지정 빌드
packer init ubuntu-2404-common/
packer build \
  -var="template_vm_id=9009" \
  -var-file="credentials.pkr.hcl" \
  -var-file="ubuntu-2404-common/ssh-credentials.pkrvars.hcl" \
  ubuntu-2404-common/
```

**동작 순서** (최대 20분 소요)
1. VMID 9008 기존 존재 시 자동 제거
2. VMID 9000 풀 클론
3. `cloud-init status --wait` 완료 대기 (apt lock 해소)
4. 패키지 설치: 기본 유틸리티, auditd, promtail, wazuh-agent
5. Ansible 공개키 등록, SSH 패스워드 인증 비활성화
6. 골든 이미지 정리: cloud-init clean, machine-id 초기화
7. post-processor: Proxmox 호스트에 SSH로 ciuser/cipassword/ipconfig0(DHCP) 재주입
8. 템플릿 변환


**로그 저장 및 확인**
```bash
# 실행 + 로그 저장
PACKER_LOG=1 packer build \
  -var-file="credentials.pkr.hcl" \
  -var-file="ubuntu-2404-common/ssh-credentials.pkrvars.hcl" \
  ubuntu-2404-common/ 2>&1 | tee /tmp/packer-debug.log

# 플러그인 미설치 시 init 먼저 실행
packer init ubuntu-2404-common/

# 오류 위치 확인
grep -A2 -B2 "exit\|error\|Error\|failed\|E:" /tmp/packer-debug.log | tail -50
```

**빌드 중 VM 상태 확인 (Proxmox 호스트에서)**
```bash
# 빌드 중 생성된 VM 목록 확인
qm list

# cloud-init 완료 여부 확인 (Packer SSH 접속 전 hang 시)
qm agent 9008 exec -- cat /var/log/cloud-init-output.log

# apt 진행 중 dpkg lock으로 멈춘 경우 확인
qm agent 9008 exec -- cat /var/run/lock/dpkg-lock-frontend

# VM 콘솔 직접 접속 (SSH 안 될 때)
qm terminal 9008
```

`dpkg lock` 에러: cloud-init이 apt를 잡고 있는 상태. Packer 첫 번째 프로비저너가 `cloud-init status --wait`으로 자동 대기하므로 정상 흐름이면 해소된다. 빌드 로그에서 `exit 100` 확인 시 apt 충돌이 원인.


**변수 파일 설명**

| 파일 | 내용 |
|---|---|
| `credentials.pkr.hcl` | Proxmox API URL, 토큰 ID/시크릿 |
| `ssh-credentials.pkrvars.hcl` | 노드명, SSH 계정, Ansible 공개키 |

**테스트 VM 생성**
```bash
qm clone 9008 200 --name test-vm --full
qm set 200 --ipconfig0 ip=dhcp
qm start 200
```
