# Ansible

컨트롤 노드 VM 생성 및 Ansible 플레이북 관리

**사용 목적**
- 초기 구축: 소프트웨어 설치, 클러스터 초기화
- 운영 자동화: 설정 변경, 노드 추가, 패치, 복구

초기 구축(`playbooks/`)과 운영(`playbooks/ops/`)은 플레이북 폴더로 구분한다. 문서 잠금은 별도로 필요 없다.

**파이프라인 (실행 순서)**

| 순서 | 폴더 | 내용 | 실행 위치 |
|---|---|---|---|
| 1 | 00.scripts | 베이스 템플릿(9000) 생성 | Proxmox 호스트 |
| 2 | 01.packer | 공통 템플릿(9003, 9005) 생성 | 빌드 서버 |
| 3 | **03.ansible** | **컨트롤 노드 VM 생성** | **Proxmox 호스트** |
| 4 | 02.terraform | VM 프로비저닝 | 컨트롤 노드 |
| 5 | **03.ansible** | **Ansible 플레이북 실행** | **컨트롤 노드** |

**디렉토리 구성**
```
03.ansible/
├── 03-create-control-node.sh   # 컨트롤 노드 VM 생성
├── 03-deploy-to-control.sh     # 로컬 → 컨트롤 노드 파일 배포
├── .env                        # VM 설정 (gitignore 대상)
├── .env.example                # 설정 템플릿
├── keys/                       # 팀원 SSH 공개키 (*.pub)
└── workspace/                  # Ansible 플레이북 및 롤
    ├── ansible.cfg
    ├── group_vars/
    │   └── all.yml             # 전체 환경 공통 변수
    ├── roles/                  # 환경 공통 롤
    │   ├── common/             # 전체 VM 공통 기본 설정
    │   ├── dns/                # CoreDNS + etcd + Keepalived
    │   ├── haproxy/            # HAProxy + Keepalived
    │   ├── registry/           # 컨테이너 레지스트리
    │   ├── k8s_common/         # k8s 공통 설정
    │   ├── k8s_master/         # k8s 마스터 노드
    │   ├── k8s_worker/         # k8s 워커 노드
    │   ├── monitor/            # 모니터링 (Grafana, Loki 등)
    │   └── ...                 # CICD, SIEM, Vault 추가 예정
    ├── playbooks/
    │   ├── site.yml            # 전체 실행
    │   ├── dns.yml
    │   ├── haproxy.yml
    │   ├── registry.yml
    │   ├── k8s.yml
    │   └── monitor.yml
    └── inventories/
        ├── test/
        │   ├── hosts
        │   ├── group_vars/     # test 전용 오버라이드
        │   └── certs/          # gitignore 대상
        └── prod/
            ├── hosts
            ├── group_vars/     # prod 전용 오버라이드
            └── certs/          # gitignore 대상
```

## 03-deploy-to-control.sh

로컬에서 Terraform + Ansible 파일을 컨트롤 노드 `~/workspace/`에 한 번에 배포.
기존 디렉토리를 제거하고 `~/workspace/{terraform,ansible}` 구조로 재구성.

> **주의**: 배포 시 컨트롤 노드의 `~/workspace/` 전체를 삭제 후 재생성.
> `credentials.auto.tfvars` 등 컨트롤 노드에서만 생성한 파일은 미리 백업 필요.

```bash
# 프로젝트 루트에서 실행, 최초 SSH 연결 시 비밀번호 1회 입력
bash 03.ansible/03-deploy-to-control.sh
```

컨트롤 노드 결과 구조:
```
~/workspace/
├── terraform/   # 02.terraform/* 전체
└── ansible/     # 03.ansible/workspace/* 전체
```

## 컨트롤 노드 실행 예시

> 전체 예시는 [EXAMPLES.md](./EXAMPLES.md) 참조

### Terraform

```bash
~/workspace/terraform/02-run.sh prod apply all
~/workspace/terraform/02-run.sh test apply all
```

### Ansible

```bash
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/site.yml
```



## 03-create-control-node.sh

VMID 9003 클론 → 컨트롤 노드 VM(VMID 2210) 생성 및 스택 자동 설치

### 스펙

| 항목 | 값 |
|---|---|
| VM ID | 2210 |
| 이름 | control |
| 클론 소스 | 9003 (ubuntu-2404-common-v1) |
| CPU | 2 cores / host |
| 메모리 | 2048 MB |
| 디스크 | 10G (rbd-storage) |
| 네트워크 | virtio / vmbr0 / VLAN 30 (폐쇄망) |
| IP | 172.16.30.7/24 |
| 게이트웨이 | 172.16.30.1 |
| 계정 | control |

### 주요 스택

cloud-init이 첫 부팅 시 자동 설치. `control` 계정만 실행 가능.

| 소프트웨어 | 용도 |
|---|---|
| Terraform | Proxmox VM 프로비저닝 |
| Ansible | VM 구성 자동화 |
| etcd | 분산 키-값 저장소 |

### 사전 조건

- VMID 9003 (ubuntu-2404-common-v1) 템플릿 존재 (`01.packer` 빌드 완료)
- Proxmox 노드에서 root로 실행

### 변수 파일

`.env.example` 복사 후 `CIPASSWORD` 수정

```bash
cp .env.example .env
```

### SSH 공개키 등록

팀원 공개키를 `keys/` 에 추가 후 sh 실행 시 자동 주입

```bash
# 예: 각자 공개키 파일 추가
echo "ssh-ed25519 AAAA... member@laptop" > keys/member.pub
```

### 실행

```bash
bash 03-create-control-node.sh
```

### 동작 순서

1. 기존 VMID 2210 존재 시 자동 제거 (Ceph RBD 잔여 이미지 포함)
2. cicustom 스니펫 생성
3. VMID 9003 풀 클론 (1~3분 소요)
4. CPU / 메모리 / 네트워크 / RNG 설정
5. cloud-init: 고정 IP / 계정 / SSH 키 / cicustom 주입
6. VM 시작 → cloud-init 실행
   - Terraform, Ansible, etcd 자동 설치
   - SSH 비밀번호 인증 활성화
   - `control` 계정 전용 실행 권한 설정
7. 설치 완료 (총 5~10분 소요)

### 로그 확인

```bash
# VM 생성 로그 (Proxmox 호스트)
tail -f /var/log/create-control-node.log

# 스택 설치 로그 (컨트롤 노드 접속 후)
cloud-init status
cat /var/log/cloud-init-done.marker
```

### 완료 확인

```bash
ssh control@172.16.30.7
terraform version
ansible --version
etcd --version
```

## 컨트롤 노드에서 실행

| 용도 | 컨트롤 노드 경로 | 저장소 경로 |
|---|---|---|
| Terraform | `~/workspace/terraform/` | `02.terraform/` |
| Ansible | `~/workspace/ansible/` | `03.ansible/workspace/` |

### 파일 전송

**방법 1: 03-deploy-to-control.sh (권장)**
```bash
# 프로젝트 루트에서 실행
bash 03.ansible/03-deploy-to-control.sh
```

**방법 2: git sparse checkout**
```bash
# 컨트롤 노드에서 실행
git clone --no-checkout --depth=1 --filter=blob:none https://github.com/<org>/kosa-final-project.git
cd kosa-final-project
git sparse-checkout set 02.terraform 03.ansible/workspace
git checkout main
cp -r 02.terraform ~/workspace/terraform
cp -r 03.ansible/workspace ~/workspace/ansible

# 이후 업데이트 시
git pull && cp -r 02.terraform ~/workspace/terraform && cp -r 03.ansible/workspace ~/workspace/ansible
```

**방법 3: scp (저장소 비공개 또는 git 미구성 시)**
```bash
# 최초 1회
scp -r 02.terraform control@172.16.30.7:~/workspace/terraform
scp -r 03.ansible/workspace control@172.16.30.7:~/workspace/ansible

# 업데이트 시
ssh control@172.16.30.7 "rm -rf ~/workspace/terraform ~/workspace/ansible"
scp -r 02.terraform control@172.16.30.7:~/workspace/terraform
scp -r 03.ansible/workspace control@172.16.30.7:~/workspace/ansible
```

### 1단계: Terraform으로 VM 생성

**Ansible 실행 전 반드시 먼저 수행**

```bash
cd ~/workspace/terraform/env/test
cp credentials.auto.tfvars.example credentials.auto.tfvars
# credentials.auto.tfvars 편집 (API 토큰, ssh_public_key 입력) 후

# 전체 실행 (Ceph clone 충돌 방지를 위해 parallelism=1 필수)
../../02-run.sh test apply all

# 역할별 배포
../../02-run.sh test apply dns
../../02-run.sh test apply k8s-master

# VM 삭제
../../02-run.sh test destroy all
```

### 2단계: Ansible SSH 접근 설정

Terraform 배포 시 `credentials.auto.tfvars`의 `ssh_public_key`가 VM cloud-init으로 `kosa` 계정에 주입됨.
컨트롤 노드에 대응하는 개인키(`~/.ssh/ansible`) 배치 필요.

```bash
ls ~/.ssh/ansible   # 존재하면 완료
```

없을 경우 새로 생성 후 공개키를 `credentials.auto.tfvars`의 `ssh_public_key`에 반영 → Terraform 재적용:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible -C "ansible@control" -N ""
cat ~/.ssh/ansible.pub   # 이 값을 credentials.auto.tfvars의 ssh_public_key에 추가
```

**접속 확인**
```bash
cd ~/workspace/ansible
ansible all -m ping
```

### 3단계: Ansible 플레이북 실행

```bash
cd ~/workspace/ansible

# prod 인벤토리 기준 (ansible.cfg 기본값)
ansible-playbook playbooks/dns.yml
ansible-playbook playbooks/site.yml

# test 인벤토리 지정
ansible-playbook -i inventories/test/hosts playbooks/site.yml
```
