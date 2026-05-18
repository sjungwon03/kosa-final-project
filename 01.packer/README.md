# Packer

- VMID 9000 (ubuntu-2404-base) 템플릿을 클론하여 용도별 템플릿 생성
- ISO 부팅 없이 cloud-init 기반 베이스 템플릿을 클론해서 구성하는 방식
- Terraform에서 `template_vm_id`를 지정해 VM 프로비저닝 시 어느 템플릿으로 생성할지 선택

| 템플릿 | VMID | 용도 |
|---|---|---|
| ubuntu-2404-common | 9003 | 일반 VM (DNS, HAProxy, Registry 등) |
| ubuntu-2404-k8s    | 9005 | K8s 노드 (kubeadm/kubelet/kubectl + containerd 사전 설치) |

- [TODO] Packer 템플릿 리팩토링: `ubuntu-2404-common`과 `ubuntu-2404-k8s` 템플릿을 단일 파일로 통합
- [TODO] Git Push시 Packer 빌드 자동화, 이미지 변경 이력 관리

**파이프라인 (실행 순서)**

| 순서 | 폴더 | 내용 | 실행 위치 |
|---|---|---|---|
| 1 | 00.scripts | 베이스 템플릿(9000) 생성 | Proxmox 호스트 |
| 2 | **01.packer** | **공통 템플릿(9003, 9005) 생성** | **빌드 서버** |
| 3 | 03.ansible | 컨트롤 노드 VM 생성 | Proxmox 호스트 |
| 4 | 02.terraform | VM 프로비저닝 | 컨트롤 노드 |
| 5 | 03.ansible | Ansible 플레이북 실행 | 컨트롤 노드 |

**디렉토리 구성**
```
01.packer/
├── ubuntu-2404-common/                     # 템플릿1 (9003): 공통 기본 패키지
│   ├── packer-ubuntu-template.pkr.hcl
│   ├── ssh-credentials.pkrvars.hcl        # SSH 계정 (gitignore)
│   ├── ssh-credentials.pkrvars.hcl.example
│   └── http/
├── ubuntu-2404-k8s/                        # 템플릿2 (9005): 9003 클론 + K8s
│   ├── packer-k8s-template.pkr.hcl
│   ├── install-k8s.sh                     # K8s 설치 스크립트 (버전 변경 시 수정)
│   ├── ssh-credentials.pkrvars.hcl        # SSH 키 경로 (gitignore)
│   └── ssh-credentials.pkrvars.hcl.example
├── credentials.pkr.hcl                     # Proxmox API 접속 정보 (gitignore)
└── credentials.pkr.hcl.example
```



## ubuntu-2404-common

### 스펙

| 항목 | 값 |
|---|---|
| VM ID | 9003 (기본값, `-var="template_vm_id=9004"` 로 변경 가능) |
| 이름 | ubuntu-2404-common-v1 |
| 클론 소스 | 9000 (ubuntu-2404-base) |
| CPU | 2 cores / host |
| 메모리 | 2048 MB |
| 디스크 | 10G (rbd-storage / Ceph rbd-team4) |
| 네트워크 | virtio / vmbr0 / VLAN 20 |
| Machine | q35 |
| OS Type | l26 (Linux 2.6+) |

### 템플릿 구성

| 항목 | 내용 |
|---|---|
| cloud-init | rbd-storage에 드라이브 생성 |
| SSH 인증 | 빌드 중 패스워드 인증 활성화(10-password.conf), 비활성화는 Ansible에서 처리 |
| qemu-guest-agent | 활성화 (Proxmox 연동) |
| 스토리지 | Ceph rbd-storage (클론 소스와 동일 풀) |
| 빌드 정보 | `/home/kosa/build-info.txt` 파일에 템플릿 이름, VMID, 빌드 시간, Git 정보 기록 |

> `cloud_init=true`가 드라이브를 새로 생성하면서 9000 템플릿의 ciuser/cipassword/ipconfig0을 초기화하므로 post-processor에서 동일한 값을 재주입 (의도적 중복)

### 기본 설치 패키지

| 패키지 | 출처 | 설명 |
|---|---|---|
| curl, wget, git, vim, net-tools | Ubuntu APT | 기본 유틸리티 |
| python3-apt | Ubuntu APT | Ansible apt 모듈 의존성 |
| auditd | Ubuntu APT | Linux 보안 감사 데몬(시스템 콜·파일 접근 이벤트 기록) 활성화는 Ansible에서 처리 |
| promtail | Grafana APT | Grafana Loki 로그 수집 에이전트 설치, 활성화는 Ansible에서 처리 |
| wazuh-agent | Wazuh 4.x APT | SIEM/보안 모니터링 에이전트 설치, 활성화는 Ansible에서 처리 |

> [!NOTE]: Node Exporter는 템플릿에 포함되지 않으며, Ansible에서 패키지 설치 및 서비스 실행을 처리함

### 기본 계정
- username: kosa
- password: `ssh-credentials.pkrvars.hcl`의 `ssh_password` 값
- sudo: NOPASSWD

### 사전 조건

- VMID 9000 (ubuntu-2404-base) 템플릿 존재
- Proxmox API 토큰 발급 후 `credentials.pkr.hcl` 작성

### 변수 파일

| 파일 | 내용 |
|---|---|
| `credentials.pkr.hcl` | Proxmox API URL, 토큰 ID/시크릿 (gitignore) |
| `ssh-credentials.pkrvars.hcl` | 노드명, SSH 계정/패스워드 (gitignore) |

```bash
# .example 파일 복사 후 수정
cp credentials.pkr.hcl.example credentials.pkr.hcl
cp ubuntu-2404-common/ssh-credentials.pkrvars.hcl.example ubuntu-2404-common/ssh-credentials.pkrvars.hcl
```

### 실행

**[방법 1] 랩퍼 스크립트를 사용한 빠른 실행**

```bash
cd 01.packer
chmod +x 01-build-9003.sh

# 9003 템플릿 빌드 실행
./01-build-9003.sh
```

**[방법 2] 수동 실행 (옵션 지정)**

```bash
cd 01.packer

packer init ubuntu-2404-common/

# 기본 빌드
packer build \
  -var-file="credentials.pkr.hcl" \
  -var-file="ubuntu-2404-common/ssh-credentials.pkrvars.hcl" \
  ubuntu-2404-common/

# VMID 지정 빌드
packer build \
  -var="template_vm_id=9003" \
  -var-file="credentials.pkr.hcl" \
  -var-file="ubuntu-2404-common/ssh-credentials.pkrvars.hcl" \
  ubuntu-2404-common/
```

**동작 순서** (최대 10분 소요)
1. VMID 9003 존재 시 자동 제거
2. VMID 9000 풀 클론
3. `cloud-init status --wait` 완료 대기 + apt lock 해소 대기
4. 패키지 설치: 기본 유틸리티, auditd, promtail, wazuh-agent
5. 골든 이미지 정리: cloud-init clean, machine-id 초기화
6. post-processor: ciuser/cipassword/ipconfig0(DHCP) 재주입, `serial0` 제거, `vga: std` 설정
7. 템플릿 변환

### 로그 확인

**로그 저장 및 확인**
```bash
# 실행 + 로그 저장
PACKER_LOG=1 packer build \
  -var-file="credentials.pkr.hcl" \
  -var-file="ubuntu-2404-common/ssh-credentials.pkrvars.hcl" \
  ubuntu-2404-common/ 2>&1 | tee /tmp/packer-debug.log

# 오류 위치 확인
grep -A2 -B2 "exit\|error\|Error\|failed\|E:" /tmp/packer-debug.log | tail -50
```

**빌드 중 VM 상태 확인 (Proxmox 호스트)**
```bash
# 빌드 중 생성된 VM 목록 확인
qm list

# cloud-init / apt 진행 상태 확인 (빌드 중에만 가능)
qm terminal 9003
```

### 테스트 VM 생성
```bash
qm clone 9003 200 --name test-vm --full
qm set 200 --ipconfig0 ip=dhcp
qm start 200
```

---

## ubuntu-2404-k8s

- 9003 클론 → K8s 노드 전용 템플릿(9005) 생성
- containerd, kubeadm, kubelet, kubectl 설치 (비활성화 상태로 구워넣음)
- Ansible은 kubeadm init/join만 수행

### 스펙

| 항목 | 값 |
|---|---|
| VM ID | 9005 (기본값, `-var="template_vm_id=9006"` 로 변경 가능) |
| 이름 | ubuntu-2404-k8s-1.32 |
| 클론 소스 | 9003 (ubuntu-2404-common) |
| CPU | 2 cores / host |
| 메모리 | 4096 MB |
| K8s 버전 | 1.32 (`install-k8s.sh`에서 수정) |

### 사전 조건
- VMID 9003 템플릿 존재 (`ubuntu-2404-common` 빌드 완료)

### 변수 파일

| 파일 | 내용 |
|---|---|
| `credentials.pkr.hcl` | Proxmox API URL, 토큰 ID/시크릿 (gitignore) |
| `ssh-credentials.pkrvars.hcl` | 노드명, SSH 계정/패스워드 (gitignore) |

```bash
# .example 파일 복사 후 수정
cp credentials.pkr.hcl.example credentials.pkr.hcl
cp ubuntu-2404-k8s/ssh-credentials.pkrvars.hcl.example ubuntu-2404-k8s/ssh-credentials.pkrvars.hcl
```

### 실행

**[방법 1] 랩퍼 스크립트를 사용한 빠른 실행**

```bash
cd 01.packer
chmod +x 01-build-9005.sh

# 9005 템플릿 빌드 실행
./01-build-9005.sh
```

**[방법 2] 수동 실행**

```bash
cd 01.packer

packer init ubuntu-2404-k8s/

packer build \
  -var-file="credentials.pkr.hcl" \
  -var-file="ubuntu-2404-k8s/ssh-credentials.pkrvars.hcl" \
  ubuntu-2404-k8s/
```

**동작 순서**
1. VMID 9003 풀 클론
2. cloud-init 완료 대기
3. `install-k8s.sh` 실행 (swap 비활성화, 커널 모듈, containerd, kubeadm/kubelet/kubectl)
4. 골든 이미지 정리 (cloud-init clean, machine-id 초기화)
5. post-processor: `serial0` 제거, `vga: std` 설정 (Proxmox 웹 콘솔 정상화)
6. 템플릿 변환