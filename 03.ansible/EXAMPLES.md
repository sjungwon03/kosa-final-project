# 실행 예시

컨트롤 노드(`172.16.30.7`) 홈 디렉토리에서 실행하는 전체 예시 모음.


## Terraform

### prod 환경

```bash
# 전체 배포
~/workspace/terraform/02-run.sh prod apply all

# 역할별 개별 배포
~/workspace/terraform/02-run.sh prod apply dns
~/workspace/terraform/02-run.sh prod apply haproxy
~/workspace/terraform/02-run.sh prod apply vault
~/workspace/terraform/02-run.sh prod apply services

# k8s: 마스터 3 + 워커 3 한 번에 배포
~/workspace/terraform/02-run.sh prod apply k8s

# k8s: 개별 배포
~/workspace/terraform/02-run.sh prod apply k8s-master
~/workspace/terraform/02-run.sh prod apply k8s-worker

# 특정 VM 1대만 배포
~/workspace/terraform/02-run.sh prod apply dns dns1

# 전체 삭제
~/workspace/terraform/02-run.sh prod destroy all
```

### test 환경 (VMID: 1xxxx, IP: .1xx)

```bash
# 전체 배포
~/workspace/terraform/02-run.sh test apply all

# 역할별 개별 배포
~/workspace/terraform/02-run.sh test apply dns
~/workspace/terraform/02-run.sh test apply k8s
~/workspace/terraform/02-run.sh test apply k8s-master
~/workspace/terraform/02-run.sh test apply k8s-worker

# 전체 삭제
~/workspace/terraform/02-run.sh test destroy all
```

---

## Ansible

### 핑 테스트

```bash
# 전체
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible all -m ping

# 그룹별
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible dns_servers -m ping
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible k8s_masters -m ping
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible k8s_workers -m ping
```

### 플레이북 실행 (Test 환경 퀵 가이드)

```bash
# DNS 설정
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/test/hosts ~/workspace/ansible/playbooks/dns.yml

# K8s 클러스터 구성
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook -i ~/workspace/ansible/inventories/test/hosts ~/workspace/ansible/playbooks/k8s.yml
```


### k8s 클러스터 구성 순서

#### prod: 마스터 3 + 워커 3 동시 (권장)

```bash
~/workspace/terraform/02-run.sh prod apply k8s
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/k8s.yml
```

#### test: 마스터 1 + 워커 1 단계별 (IP: .130, .141)

```bash
# 1. 마스터 프로비저닝 + 초기화 (172.16.30.130)
~/workspace/terraform/02-run.sh test apply k8s-master
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook \
  -i ~/workspace/ansible/inventories/test/hosts \
  ~/workspace/ansible/playbooks/k8s.yml --limit k8s_masters

# 2. 워커 프로비저닝 + 조인 (172.16.30.141)
~/workspace/terraform/02-run.sh test apply k8s-worker
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook \
  -i ~/workspace/ansible/inventories/test/hosts \
  ~/workspace/ansible/playbooks/k8s.yml --limit k8s_workers
```



---

## prod 전체 구성 시나리오

### 1. 기초 인프라 (VLAN 30)

```bash
# DNS 서버 생성
~/workspace/terraform/02-run.sh prod apply dns

# DNS/etcd 설정
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/dns.yml
```

### 2. 외부 관문 (VLAN 20)

```bash
# HAProxy 서버 생성
~/workspace/terraform/02-run.sh prod apply haproxy

# HAProxy/VIP 설정
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/haproxy.yml
```

### 3. K8s 클러스터 (VLAN 30)

```bash
# K8s 노드 전체 생성
~/workspace/terraform/02-run.sh prod apply k8s

# K8s 핑 테스트
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible k8s_cluster -m ping

# K8s 클러스터 구성
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/k8s.yml
```

### 4. 기타 서비스 (보안/저장소/모니터링)

```bash
# Vault 서버 생성 및 설정
~/workspace/terraform/02-run.sh prod apply vault
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/vault.yml

# CICD 서버 생성 및 설정
~/workspace/terraform/02-run.sh prod apply cicd
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/cicd.yml

# Registry(Harbor) 서버 생성 및 설정
~/workspace/terraform/02-run.sh prod apply registry
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/registry.yml

# SIEM(Wazuh) 서버 생성 및 설정
~/workspace/terraform/02-run.sh prod apply siem
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/siem.yml

# Monitoring(PLG) 서버 생성 및 설정
~/workspace/terraform/02-run.sh prod apply monitor
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg ansible-playbook ~/workspace/ansible/playbooks/monitor.yml
```


---

## 운영 (ops)

플레이북은 공통으로 사용하고, `-i` 옵션으로 환경(prod/test)만 전환한다.

### 보안 패치 (Rolling Update)

```bash
# prod — 한 번에 1대씩 순차 패치 (서비스 중단 방지)
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/ops/patch.yml

# test
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
ansible-playbook -i ~/workspace/ansible/inventories/test/hosts \
  ~/workspace/ansible/playbooks/ops/patch.yml
```

### K8s 워커 노드 추가 (Scale Out)

```bash
# 1. tfvars에 신규 워커 정보 추가 후 프로비저닝
~/workspace/terraform/02-run.sh prod apply k8s-worker

# 2. 신규 노드만 대상으로 앤서블 실행 (기존 노드 영향 없음)
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/ops/add-worker.yml --limit 172.16.30.44
```

### 설정 동기화 (Configuration Drift 복구)

누군가 서버를 직접 수정했을 경우, 앤서블 코드 기준으로 되돌린다.

```bash
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
ansible-playbook -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/ops/sync.yml
```

---

## Terraform — 초기 프로비저닝 vs 운영

### 초기 프로비저닝 (최초 1회)

VM을 새로 만드는 단계. tfvars에 VM 정보를 추가하고 `apply` 실행.

```bash
# 역할별 순차 생성 (권장 순서)
~/workspace/terraform/02-run.sh prod apply dns
~/workspace/terraform/02-run.sh prod apply haproxy
~/workspace/terraform/02-run.sh prod apply k8s
~/workspace/terraform/02-run.sh prod apply vault
~/workspace/terraform/02-run.sh prod apply services
```

### 운영 중 변경

이미 떠 있는 VM의 **스펙(메모리·CPU·디스크)** 을 변경할 때 사용.
재생성 없이 변경된 부분만 적용된다.

```bash
# tfvars 수정 후 (예: 메모리 4096 → 8192)
~/workspace/terraform/02-run.sh prod apply k8s

# 변경 내용 사전 확인 (실제 적용 전)
~/workspace/terraform/02-run.sh prod plan k8s
```

> **주의**: VM 이름(`key`) 또는 VMID를 변경하면 Terraform이 기존 VM을 삭제하고 재생성한다.
> 스펙 변경만 할 경우 반드시 이름·VMID는 그대로 유지할 것.

### 특정 VM 1대만 제거

```bash
terraform -chdir=~/workspace/terraform/env/prod \
  destroy -target='module.vms.proxmox_virtual_environment_vm.ubuntu["k8s-worker-03"]'
```

### 운영 중 금지 명령어

| 명령어 | 사유 |
|---|---|
| `destroy all` | 전체 삭제 — 운영 중 절대 실행 금지 |
| `destroy k8s` | K8s 노드 전체 삭제 — 데이터 유실 위험 |
