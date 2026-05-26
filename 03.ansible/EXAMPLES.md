# EXAMPLES

컨트롤 노드의 홈 디렉토리에서 실행하는 전체 예시 모음

- [Terraform](#terraform)
- [Ansible](#ansible)

> 폐쇄망 전환 전 Nexus 준비 체크리스트는 `03-1.nexus/README.md` 참조

---

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

**방법 3: Proxmox 노드 자체가 다운된 경우 (HTTP 595 / No route to host)**
`terraform destroy` 시 특정 노드에서 `No route to host` 에러 발생 → 노드 복구 전까지 Terraform 상태에서 제거 후 수동 정리

```bash
# 1. Terraform 환경 디렉터리로 이동 (반드시 env 하위에서 실행)
cd ~/workspace/terraform/env/prod   # 또는 env/test

# 2. 상태에서 해당 VM 제거 (Terraform이 더 이상 관리하지 않음)
terraform state rm 'module.vms.proxmox_virtual_environment_vm.ubuntu["<VM명>"]'
# 예: terraform state rm 'module.vms.proxmox_virtual_environment_vm.ubuntu["k8s-master-02"]'

# 3. 노드 복구 후 실제 VM 강제 삭제
bash ~/workspace/terraform/02-force-destroy-all.sh kosa23
# 특정 VM만: bash ~/workspace/terraform/02-force-destroy-all.sh kosa23 2232
```

> 현재 상태 목록 확인: `terraform state list`

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


// 적절한 위치에 삽입

# 전체 서버 promtail/wazuh-agent 상태 일괄 확인
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible -i ~/workspace/ansible/inventories/prod/hosts \
  all -m shell -a "systemctl is-active promtail wazuh-agent prometheus-node-exporter" \
  --become


  

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
