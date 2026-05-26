# Scripts

- Proxmox 호스트에서 직접 실행하는 쉘 스크립트 모음
- Packer가 클론할 베이스 템플릿(VMID 9000)을 생성하고 문제 발생 시 VM을 강제 제거

**파이프라인 (실행 순서)**

| 순서 | 폴더 | 내용 | 실행 위치 |
|---|---|---|---|
| 1 | **00.scripts** | **베이스 템플릿(9000) 생성** | **Proxmox 호스트** |
| 2 | 01.packer | 공통 템플릿(9005) 생성 | 빌드 서버 |
| 3 | 03.ansible | 컨트롤 노드 VM 생성 | Proxmox 호스트 |
| 4 | 02.terraform | VM 프로비저닝 | 컨트롤 노드 |
| 5 | 03.ansible | Ansible 플레이북 실행 | 컨트롤 노드 |

**스크립트 목록**
- 00-create-ubuntu-2404-base.sh
- 00-force-destroy-vm.sh

---

## 00-create-ubuntu-2404-base.sh

- Ubuntu 24.04 cloud-init 베이스 템플릿(VMID 9000)을 생성
- Packer가 이 템플릿을 클론하여 Ansible 관리용 공통 템플릿(9005)을 생성

### 스펙

| 항목 | 값 |
|---|---|
| VM ID | 9000 (기본값, 인자로 변경 가능) |
| 이름 | ubuntu-2404-base |
| CPU | 2 cores / host |
| 메모리 | 2048 MB |
| 디스크 | 10G (rbd-storage / Ceph rbd-team4) |
| 네트워크 | virtio / vmbr0 / VLAN 20 |
| cloud-init | ciuser: kosa / ipconfig: DHCP |

> VLAN 20 경우 테라폼을 통해 가상 서버별 다시 설정

### 사전 조건

- Proxmox 노드에서 root로 실행
- 인터넷 연결 (Ubuntu cloud image 다운로드, APT 패키지 설치)
- Ceph rbd-storage 연결 상태 (불가 시 local-lvm 자동 폴백)

### 실행

```bash
# 기본 템플릿 생성
bash 00-create-ubuntu-2404-base.sh
bash 00-create-ubuntu-2404-base.sh 9002

# 로그 확인
tail -f /var/log/create-ubuntu-template.log
```

**완료까지 최대 15분 소요**: VM 부팅 후 cloud-init이 qemu-guest-agent를 설치할 때까지 대기

### 동작 순서

1. 기존 VMID 9000 존재 시 자동 제거
2. Ubuntu 24.04 cloud image 다운로드 (기존 파일 있으면 재사용)
3. `virt-customize`로 이미지 오프라인 수정
   - snapd 제거 (불필요한 서비스, 부팅 지연 원인)
   - ttyS0 자동 로그인 적용 (`qm terminal`로 콘솔 접속 시 사용)
4. cicustom 스니펫 생성
   - cicustom은 Proxmox의 cloud-init 확장 기능으로 VM 첫 부팅 시 사용자 정의 스크립트 실행
   - qemu-guest-agent 설치 및 활성화 (Proxmox ↔ VM 통신에 필요)
   - SSH 패스워드 인증 활성화 (Ubuntu cloud image 기본값 비활성화)
5. VM 생성 및 디스크 임포트 → 10G 리사이즈
6. cloud-init 설정 (ciuser / DHCP / cicustom 연결)
7. VM 부팅 → qemu-guest-agent 응답 대기 (최대 15분)
8. VM 종료 → cicustom 제거 → 템플릿 변환

> cicustom 템플릿 변환 전 제거: 스니펫 경로가 클론 후에도 남아있으면 다른 노드에서 해당 경로를 찾지 못해 오류가 발생함

---

## 00-force-destroy-vm.sh

- 유령 상태 VM을 강제 제거
- 유령 상태란 `qm list`에는 없지만 conf 파일이 남아있어 동일 VMID로 생성이 안 되는 상태

### 실행

```bash
bash 00-force-destroy-vm.sh <VMID>
```

### 예시

```bash
bash 00-force-destroy-vm.sh 9000
```
