# 03.ansible 트러블슈팅 가이드

이 문서는 인프라 구축 및 쿠버네티스 설치 과정에서 발생한 주요 장애 상황과 해결 방법을 기록합니다.

---

## [Issue 1] K8s 마스터 조인 시 변수 미정의 (Undefined Variable)
### 현상
- `k8s_master` 롤 실행 중 `master_join_cmd_raw` 변수를 찾을 수 없다는 에러 발생.
- 마스터 02, 03번 노드에서 조인 단계 진행 불가.

### 원인
- 마스터 01번이 실패하거나 스킵될 경우, 해당 호스트에 등록된 `register` 변수가 다른 호스트(02, 03)의 `hostvars`에 노출되지 않음.

### 해결 (Solution)
- `set_fact` 모듈을 사용하여 마스터 01번에서 생성한 토큰과 인증서 키를 **전역 변수(`shared_master_join_cmd`, `shared_cert_key`)**로 승격시킴.
- `run_once: true` 설정을 통해 클러스터 내 모든 노드가 동일한 조인 정보를 확실히 인지하도록 개선.

---

## [Issue 2] Calico CNI 설치 시 I/O Timeout 발생
### 현상
- `kubectl apply -f calico.yaml` 실행 시 `https://172.16.20.25:6443`으로 접속을 시도하다 타임아웃 발생.

### 원인
- `kubeadm init` 직후에는 로드밸런서(VIP)와 마스터 노드 간의 통신이 불안정하거나, HAProxy가 백엔드(마스터)를 아직 인식하지 못한 상태일 수 있음.
- `kubectl`이 기본적으로 유효성 검사(Validation)를 위해 VIP에 접속하려다 실패함.

### 해결 (Solution)
- **로컬 직접 호출**: `--server=https://127.0.0.1:6443` 옵션을 추가하여 VIP를 거치지 않고 마스터 자신의 API 서버에 직접 명령을 내림.
- **검증 생략**: `--validate=false` 및 `--insecure-skip-tls-verify` 옵션을 추가하여 외부 의존성을 완전히 제거하고 설치 강행.

---

## [Issue 3] SSH 접속 시 "Too many authentication failures"
### 현상
- `03-deploy-to-control.sh` 실행 중 비밀번호를 입력하기도 전에 연결이 끊김.

### 원인
- 로컬 PC에 등록된 SSH 키가 너무 많아 서버의 보안 정책(`MaxAuthTries`)에 의해 차단됨.

### 해결 (Solution)
- `ssh-add -D` 명령어를 사용하여 현재 세션의 임시 SSH 키들을 초기화한 후 재시도.

---

## 이전 설치 제거 기준

### 재배포만으로 충분한 경우 (리셋 불필요)

앤서블은 멱등성을 보장하므로, 아래 상황에서는 이전 설치를 제거하지 않고 플레이북을 다시 실행하면 된다.

| 상황 | 이유 |
|---|---|
| 설정 파일(`.cfg`, `.conf`)만 변경 | 템플릿 덮어쓰기 후 서비스 재시작으로 반영됨 |
| 변수값 변경 (포트, IP, 비밀번호 등) | 위와 동일 |
| 서비스가 죽어있을 때 | `state: started`로 자동 재기동 |

---

### 이전 설치를 제거해야 하는 경우 (리셋 필요)

| 상황 | 이유 |
|---|---|
| **설치 중 중단·실패** | 손상된 패키지(`dpkg` 잠금) 또는 불완전한 설정 파일 잔해가 남아 재설치 충돌 유발 |
| **패키지 버전 변경** | `apt`는 이미 설치된 버전이 있으면 통과 처리 — 버전이 바뀌지 않음 |
| **설정 파일 경로·구조 변경** | 앤서블은 새 경로에 파일을 생성할 뿐, 기존 경로의 파일을 자동 삭제하지 않음 |
| **상태를 가지는 서비스** (K8s, etcd, Vault) | 이전 초기화 데이터가 남아있으면 재초기화 불가 |

---

### 서비스별 제거 명령어

#### HAProxy / Keepalived

```bash
ansible loadbalancers -m shell \
  -a "apt remove -y haproxy keepalived; apt autoremove -y; \
      rm -f /etc/keepalived/keepalived.conf /etc/haproxy/haproxy.cfg" -b
```

#### K8s 클러스터 (kubeadm)

```bash
# 전체 노드
ansible k8s_cluster -m shell \
  -a "kubeadm reset -f && rm -rf /etc/kubernetes/ /var/lib/etcd/ /home/kosa/.kube/" -b

# 마스터만
ansible k8s_masters -m shell \
  -a "kubeadm reset -f && rm -rf /etc/kubernetes/ /var/lib/etcd/ /home/kosa/.kube/" -b
```

#### DNS (CoreDNS / etcd)

```bash
ansible dns_servers -m shell \
  -a "systemctl stop coredns etcd keepalived; \
      rm -rf /var/lib/etcd /etc/coredns /etc/keepalived/keepalived.conf; \
      rm -f /etc/systemd/system/etcd.service /etc/systemd/system/coredns.service; \
      systemctl daemon-reload" -b
```

> **주의**: 제거 후에는 반드시 `03-deploy-to-control.sh`로 최신 코드를 동기화한 뒤 플레이북을 재실행한다.

---

## [Issue 4] apt 잠금 오류 (Failed to lock apt)

### 현상

```
msg: 'Failed to lock apt for exclusive operation:
     E:Could not get lock /var/lib/apt/lists/lock.
     It is held by process XXXX (python3)'
```

또는 `apt-get update` 명령이 응답 없이 멈춤.

### 원인

VM 생성 직후 `unattended-upgrades`(자동 보안 업데이트) 또는 이전에 중단된 apt 프로세스가 잠금 파일을 점유하고 있는 상태. Ubuntu 22.04/24.04에서 VM 부팅 후 수 분 간 자동으로 실행되므로 매우 자주 발생한다.

### 해결 (Solution)

해당 서버에 직접 SSH로 접속하여 잠금을 제거한다.

```bash
# HAProxy 서버 예시 (172.16.20.26)
ssh kosa@172.16.20.26

# 1. 잠금을 잡고 있는 프로세스 확인
sudo lsof /var/lib/apt/lists/lock

# 2. 해당 PID 강제 종료
sudo kill -9 <PID>

# 3. 잠금 파일 삭제
sudo rm -f /var/lib/apt/lists/lock \
           /var/lib/dpkg/lock \
           /var/lib/dpkg/lock-frontend

# 4. dpkg 복구
sudo dpkg --configure -a

# 5. 패키지 목록 갱신 후 설치
sudo apt-get update
sudo apt-get install -y haproxy keepalived
```

### 예방 (Packer 템플릿 개선 TODO)

Packer 빌드 시 `unattended-upgrades`를 비활성화하면 VM 생성 직후 잠금 충돌을 원천 방지할 수 있다.

```bash
# Packer inline 또는 Ansible 프로비저너에 추가
sudo systemctl disable --now unattended-upgrades
sudo apt-get remove -y unattended-upgrades
```
