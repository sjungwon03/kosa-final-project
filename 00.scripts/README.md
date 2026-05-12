# Scripts

가상 서버 기본 템플릿 구성을 위한 쉘 스크립트 모음

- create-ubuntu-2404-base.sh
- force-destroy-vm.sh



## create-ubuntu-2404-base.sh

Ubuntu 24.04 cloud-init 베이스 템플릿(VMID 9000) 생성

**사전 조건**
- Proxmox 노드에서 root로 실행
- Ceph rbd-storage 연결 상태 (불가 시 local-lvm 자동 폴백)


**실행**
```bash
# base 템플릿 생성
bash create-ubuntu-2404-base.sh
bash create-ubuntu-2404-base.sh 9000

# 다른 터미널에서 진행 상황 확인 (VM 부팅 후)
qm agent 9000 exec -- cat /var/log/cloud-init-output.log
```

**동작 순서**
1. 기존 VMID 9000 존재 시 자동 제거
2. Ubuntu 24.04 cloud image 다운로드 (기존 파일 있으면 재사용)
3. `virt-customize`로 이미지 수정: snapd 제거, ttyS0 자동 로그인 적용
4. cicustom 스니펫 생성 (cloud-init이 부팅 시 처리: qemu-guest-agent 설치, SSH 패스워드 인증 활성화)
5. VM 생성 및 디스크 임포트 → 10G 리사이즈
6. cloud-init 설정 (ciuser: kosa / cipassword:  / DHCP / cicustom 연결)
7. VM 부팅 → qemu-guest-agent 응답 대기 (최대 15분)
8. VM 종료 → cicustom 제거 → 템플릿 변환



## force-destroy-vm.sh

유령 상태 VM 강제 제거 (conf 파일만 남고 qm list에 없는 경우)

**실행**
```bash
bash force-destroy-vm.sh <VMID>
```

**예시**
```bash
bash force-destroy-vm.sh 9001
```