# 트러블슈팅

Proxmox / 인프라 운영 중 발생한 이슈 기록

---

## Proxmox HA

### HA 리소스 삭제 stuck (`deleting` 상태)

**증상**
```
service vm:100 (kosa24, deleting)
```
`pvesh delete /cluster/ha/resources/vm:100` 실행 시 `not HA managed` 오류

**원인**: HA CRM이 삭제 완료 처리를 못 하고 멈춘 상태

**해결**: HA 마스터 노드에서 서비스 재시작
```bash
# [HA 마스터 노드 — ha-manager status에서 master 확인]
systemctl restart pve-ha-crm pve-ha-lrm
```

그래도 안 되면 설정 파일 직접 제거
```bash
grep -n "vm:100" /etc/pve/ha/resources.cfg
sed -i '/vm:100/,/^$/d' /etc/pve/ha/resources.cfg
systemctl restart pve-ha-crm pve-ha-lrm
```

---

## pfSense

### 대시보드에서 "cloud-init 드라이브를 찾을 수 없음" 경고

**증상**: Proxmox 웹 UI에서 VM 100(pfSense) cloud-init 관련 경고 출력

**원인**: VM Hardware에 Cloud-Init 탭은 활성화되어 있으나 실제 드라이브가 없는 상태

**확인**
```bash
qm config 100 | grep -E "cloudinit|ide|cdrom"
# ide2: none,media=cdrom → 빈 CD-ROM 슬롯, 무해함
```

**해결**: Proxmox 웹 UI → VM 100 → Hardware → Cloud-Init Drive 항목 Remove
- VM 데이터에 영향 없음 (드라이브 항목 설정만 제거)

---

## Ansible // 이건 여기에 정리할 내용이 아님 ㅡㅡ 

### MetalLB / Ceph CSI 태스크 전부 skip (`skipped=28`)

**증상**: `k8s.yml` 실행 후 `kubectl get storageclass`, `kubectl get pods -n metallb-system` 결과 없음. PLAY RECAP에서 `failed=0`이지만 `skipped` 수가 많음

**원인**: `inventories/prod/group_vars/all.yml` 파일 누락 — Ansible은 인벤토리 경로 기준 `group_vars/`를 로드하므로 이 파일이 없으면 `metallb_enabled`, `ceph_storage_enabled` 변수를 못 찾아 전부 skip

**확인**
```bash
# [컨트롤 노드]
grep -E "metallb_enabled|ceph_storage_enabled" ~/workspace/ansible/inventories/prod/group_vars/all.yml
```

**해결**: `inventories/prod/group_vars/all.yml` 생성 후 동기화 재실행
```bash
# [로컬]
bash 03.ansible/03-deploy-to-control.sh

# [컨트롤 노드]
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/k8s.yml
```
