# EXAMPLES

컨트롤 노드의 홈 디렉토리에서 실행하는 전체 예시 모음

- [Terraform](#terraform)
- [Ansible](#ansible)

## Terraform

### 운영 환경 (prod)
```bash
# 전체 VM 생성 (all)
~/workspace/terraform/02-run.sh prod apply all

# 개별 그룹 생성 (dns, k8s 등)
~/workspace/terraform/02-run.sh prod apply dns
~/workspace/terraform/02-run.sh prod apply k8s

# 특정 VM 1대만 생성
~/workspace/terraform/02-run.sh prod apply all dns1

# 전체 VM 제거 (주의)
~/workspace/terraform/02-run.sh prod destroy all

# 캐싱 제거 (상태 꼬임 발생 시)
rm -rf ~/workspace/terraform/env/prod/.terraform/ ~/workspace/terraform/env/prod/.terraform.lock.hcl
```

### 테스트 환경 (test)
```bash
# 전체 VM 생성
~/workspace/terraform/02-run.sh test apply all

# 개별 그룹 생성
~/workspace/terraform/02-run.sh test apply k8s

# 전체 VM 제거
~/workspace/terraform/02-run.sh test destroy all

# 캐싱 제거
rm -rf ~/workspace/terraform/env/test/.terraform/ ~/workspace/terraform/env/test/.terraform.lock.hcl
```

### 강제 리소스 정리

**방법 1: 스크립트 실행**
Terraform `destroy`로 지워지지 않는 유령 VM 및 RBD 락 발생 시 사용
```bash
# 특정 노드 전체 정리
bash ~/workspace/terraform/02-force-destroy-all.sh kosa21

# 특정 노드의 특정 VMID만 정리
bash ~/workspace/terraform/02-force-destroy-all.sh kosa21 2131
```

**방법 2: Proxmox 호스트 수동 제거**
스크립트 작동 불능 시 해당 Proxmox 호스트 쉘에서 직접 실행
```bash
# VMID 2211인 경우
qm stop 2211 --skiplock
qm destroy 2211 --purge
rm -f /etc/pve/nodes/*/qemu-server/2211.conf
```

---

## Ansible

### 초기 구축 (Provisioning)
최초 1회 실행하여 전체 스택 설치

> **주의**: `site.yml`은 vault, siem을 포함하지 않음 (폐쇄망 패키지 미러 구성 전까지 주석 유지)
> vault, siem은 미러 구성 완료 후 별도 실행 필요

```bash
# 전체 사이트 구축 (vault, siem 제외)
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts ~/workspace/ansible/playbooks/site.yml

# 특정 역할만 초기 구축
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts ~/workspace/ansible/playbooks/dns.yml
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts ~/workspace/ansible/playbooks/minio.yml
```

### DB 클러스터 초기 구축

> **주의**: PXC는 반드시 아래 순서를 지켜야 함. 순서 틀리면 클러스터 broken 상태 발생

```bash
# 1단계: 첫 번째 노드만 bootstrap 모드로 시작
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/db.yml \
  --limit 172.16.30.65 -e pxc_bootstrap=true

# 2단계: 나머지 노드 조인 (첫 번째 노드가 running 상태일 때 실행)
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/db.yml \
  --limit 172.16.30.66,172.16.30.67

# 3단계: 부트스트랩 노드를 일반 모드로 재시작 (bootstrap.service → mysql)
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/db.yml \
  --limit 172.16.30.65

# 4단계: ProxySQL 설치 (db_nodes 클러스터 정상 확인 후)
# ProxySQL 백엔드 등록은 최초 1회 수동 설정 필요 (OPERATIONS.md 참조)
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/db.yml \
  --limit proxysql
```

### 운영 및 변경 (Operation)
구축 완료 후 설정 변경 또는 패치 적용

**1. 설정 파일 업데이트 (Tag 사용)**
전체 실행 대신 특정 역할의 설정만 갱신
```bash
# HAProxy 설정만 갱신
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts ~/workspace/ansible/playbooks/haproxy.yml --tags config
```

**2. 특정 노드 유지보수 (Limit 사용)**
특정 서버 1대만 패치 또는 재시작
```bash
# 31번 마스터 노드만 작업
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts ~/workspace/ansible/playbooks/k8s.yml --limit 172.16.30.31
```

### 구성 변경 가이드
| 구분 | 수정 가능 (Apply) | 재생성 필요 (Destroy & Apply) |
|---|---|---|
| **Terraform** | CPU/RAM 할당량, 태그 | **IP 주소, 호스트네임, VM ID, 스토리지 크기(축소)** |
| **Ansible** | 서비스 설정(conf), 패키지 설치, 유저 | **OS 커널 변경, 파일시스템 레이아웃 변경** |

### 복구 및 제거
```bash
# K8s 노드 리셋
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts ~/workspace/ansible/playbooks/ops/k8s-reset.yml --limit <IP>

# SSH 소켓 캐시 제거 (접속 에러 시)
rm -rf ~/.ansible/cp/*
```
