# 공통 트러블슈팅

**목적**: 서비스 구분 없이 반복 발생하는 공통 장애 기록
**원칙**: 특정 서비스에만 해당하는 장애는 해당 런북(`03.runbooks/`)에 작성

---

## 작성 템플릿

```
## [Issue N] 제목

### 현상
[발생하는 현상 또는 에러 메시지]

### 원인
[근본 원인]

### 해결 (Solution)
[해결 방법 또는 명령어]
```

---

## Ansible

## [Issue 1] apt 잠금 오류 (Failed to lock apt)

### 현상

```
Failed to lock apt for exclusive operation:
E:Could not get lock /var/lib/apt/lists/lock.
```

또는 `apt-get update` 명령이 응답 없이 멈춤

### 원인

VM 생성 직후 `unattended-upgrades`(자동 보안 업데이트)가 apt를 잠금(lock)
Ubuntu 22.04/24.04에서 VM 부팅 후 수 분 간 자동 실행됨

### 해결 (Solution)

플레이북 재실행 — common role이 lock 해제 대기를 자동 처리함
직접 해제가 필요한 경우:

```bash
# 잠금 프로세스 확인
sudo lsof /var/lib/apt/lists/lock

# PID 강제 종료 후 잠금 파일 삭제
sudo kill -9 <PID>
sudo rm -f /var/lib/apt/lists/lock /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend
sudo dpkg --configure -a
```

---

## [Issue 2] promtail / wazuh-agent 서비스 미기동

### 현상

common role 실행 후 promtail 또는 wazuh-agent가 `inactive` 또는 `unknown` 상태

### 원인

Packer 이미지(9005)에 해당 서비스가 미설치된 상태로 클론됨
`failed_when: false` 처리로 플레이북은 통과되나 서비스는 기동되지 않음

### 해결 (Solution)

전체 서버 일괄 상태 확인 후 미기동 서버에 해당 서비스 별도 설치

```bash
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible -i ~/workspace/ansible/inventories/prod/hosts \
  all -m shell -a "systemctl is-active promtail wazuh-agent prometheus-node-exporter" \
  --become
```

---

---

## Terraform

## [Issue 1] .terraform/ 캐시 잔류 (Backend configuration changed)

### 현상

```
Backend configuration changed. To update the configuration, you must run "terraform init" again.
```

또는 MinIO 백엔드 이관 후 컨트롤 노드에 `.terraform/terraform.tfstate` 잔류

### 원인

`.terraform/` 디렉토리가 이전 backend 설정을 캐싱한 채 남아있음
MinIO 백엔드 이관 또는 `main.tf` backend 블록 수정 후 발생

### 해결 (Solution)

`.terraform/` 삭제 후 재초기화 (실제 state 파일과 무관)

```bash
rm -rf ~/workspace/terraform/env/prod/.terraform/
```

이후 `02-run.sh` 실행 시 `terraform init -reconfigure`로 자동 재초기화됨

---

## [Issue 3] SSH "Too many authentication failures"

### 현상

`03-deploy-to-control.sh` 실행 중 비밀번호 입력 전 연결이 끊김

### 원인

로컬 PC에 등록된 SSH 키가 너무 많아 서버의 보안 정책(`MaxAuthTries`)에 의해 차단됨

### 해결 (Solution)

```bash
# 현재 세션의 임시 SSH 키 초기화 후 재시도
ssh-add -D
```

