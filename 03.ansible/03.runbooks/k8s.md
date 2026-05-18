# K8s

**스택**
- kubeadm: 클러스터 초기화 및 노드 조인
- Keepalived: API 서버 VIP (172.16.30.30)
- Calico: CNI (pod_network_cidr: 192.168.0.0/16)
- containerd: 컨테이너 런타임
- Ceph CSI(RBD): 동적 PV 프로비저닝 (`rbd-storage` StorageClass)
- MetalLB: LoadBalancer 주소풀 (172.16.30.200~249)

**노드 구성**

| 역할 | 호스트명 | IP |
|---|---|---|
| API VIP | — | 172.16.30.30 |
| control-plane | k8s-master-01 | 172.16.30.31 |
| control-plane | k8s-master-02 | 172.16.30.32 |
| control-plane | k8s-master-03 | 172.16.30.33 |
| worker (플랫폼) | k8s-node-plat | 172.16.30.40 |
| worker | k8s-node-01 | 172.16.30.45 |
| worker | k8s-node-02 | 172.16.30.46 |
| worker | k8s-node-03 | 172.16.30.47 |


## K8s 구축 (설치)

> 최초 1회 실행

**배포**
```bash
# Terraform VM 생성
bash ~/workspace/terraform/02-run.sh prod apply k8s

# Ansible 서비스 구성
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/k8s.yml
```

### Ceph StorageClass 자동 적용

`k8s.yml` 마지막 단계에서 아래 순서로 자동 적용됨
1. Ceph CSI(RBD) Helm 차트 설치/업그레이드
2. Ceph CSI Secret 생성
3. `rbd-storage` StorageClass 생성

설정 파일: `workspace/group_vars/all.yml`
- `ceph_csi_enabled`
- `ceph_csi_chart_version`
- `ceph_csi_monitors`
- `ceph_rbd_cluster_id`
- `ceph_csi_user_id`
- `ceph_csi_user_key`
- `ceph_storage_enabled` (기본 `true`)

현재 team4 기준 값:
```yaml
ceph_rbd_cluster_id: "861f6095-c334-413a-95a0-04e197f430c2"
ceph_rbd_pool: "rbd-team4"
ceph_csi_user_id: "team4-k8s-csi"   # ceph auth id는 client. 접두어 제외
ceph_csi_user_key: "AQCdgwlqMDIwKRAAO1t079BPaR/p+l7Xb9SuYw=="
ceph_csi_monitors:
  - "10.10.10.11:6789"
  - "10.10.10.12:6789"
  - "10.10.10.13:6789"
  - "10.10.10.14:6789"
  - "10.10.10.15:6789"
  - "10.10.10.16:6789"
```

검증:
```bash
kubectl get sc rbd-storage
kubectl -n kube-system get secret ceph-csi-rbd-secret
```

### MetalLB 자동 설치 및 주소풀 적용

`k8s.yml` 마지막 단계에서 아래 순서로 자동 적용됨
1. MetalLB 네이티브 매니페스트 설치
2. `controller`, `speaker` rollout 대기
3. `IPAddressPool`, `L2Advertisement` 생성/적용

설정 파일: `workspace/group_vars/all.yml`
- `metallb_enabled`
- `metallb_manifest_url`
- `metallb_namespace`
- `metallb_ipaddresspool_name`
- `metallb_l2advertisement_name`
- `metallb_address_pools`

기본값:
```yaml
metallb_enabled: true
metallb_address_pools:
  - "172.16.30.200-172.16.30.249"
```

---

## 서비스 확인 (검증)

> 배포/재배포 완료 후 클러스터 무결성 테스트

### 1. 인프라 및 노드 상태 확인
```bash
# 모든 노드 상태 및 버전 확인 (전체 Ready 여부 체크)
kubectl get nodes -o wide

# 모든 네임스페이스의 포드 상태 확인 (에러 포드 유무 체크)
kubectl get pods -A
```

### 2. 컨트롤 플레인 및 etcd 상태 (심층 검증)
```bash
# etcd 클러스터 헬스 체크 (모든 노드 healthy 확인)
kubectl -n kube-system exec etcd-k8s-master-01 -- etcdctl \
  --endpoints=https://172.16.30.31:2379,https://172.16.30.32:2379,https://172.16.30.33:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key \
  endpoint health

# etcd 멤버 목록 최종 확인 (ID 및 IP 일치 여부)
kubectl -n kube-system exec etcd-k8s-master-01 -- etcdctl \
  --endpoints=https://172.16.30.31:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key \
  member list
```

### 3. 고가용성(HA) VIP 및 서비스 확인
```bash
# 로드밸런서 VIP(172.16.30.30)를 통한 API 서버 응답 확인
curl -k https://172.16.30.30:6443/version

# CoreDNS 및 Calico 동작 확인
kubectl get pods -n kube-system | grep -E 'coredns|calico'
```


## 트러블슈팅

**추가 마스터 ROLES: `<none>` (control-plane 조인 실패)**
- **증상**: kubectl get nodes에서 master-02 또는 master-03의 ROLES가 `<none>`, etcd 파드 재시작 반복
- **원인**: `--limit`으로 플레이북 재실행 시 master-01이 제외되어 `master_join_cmd_raw` 변수 미등록 → `kubeadm join --control-plane` 미실행
- **해결**:
```bash
# 1단계 — 컨트롤 노드에서: etcd stale 멤버 제거 (필수)
# 마스터 노드 중 한 곳의 etcd 포드에 접속하여 멤버 목록 확인
kubectl -n kube-system exec etcd-k8s-master-01 -- etcdctl \
  --endpoints=https://172.16.30.31:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key \
  member list

# 대상 ID 확인 후 제거 (예: master-03 ID가 659be... 인 경우)
kubectl -n kube-system exec etcd-k8s-master-01 -- etcdctl \
  --endpoints=https://172.16.30.31:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key \
  member remove <Target_ID>

# 2단계 — master-01에서: 쿠버네티스 노드 객체 제거
kubectl drain k8s-master-03 --ignore-daemonsets --delete-emptydir-data
kubectl delete node k8s-master-03

# 3단계 — 문제 노드(master-03)에서: 완전 초기화
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet /etc/cni/net.d
sudo systemctl restart containerd

# 4단계 — 컨트롤 노드에서: master-01 포함하여 플레이북 재실행
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/k8s.yml \
  --limit 172.16.30.31,172.16.30.33
```
> master-01을 같이 포함해야 `master_join_cmd_raw` 변수가 정상적으로 등록되어 조인이 가능함

**API 서버 응답 타임아웃**
- **증상**: kubeadm init/join 중 `could not download the kube-proxy configuration from ConfigMap` 에러
- **원인**: 마스터 동시 조인 시 API 서버 일시 과부하
- **해결**: 플레이북 재실행 (멱등성 보장 — `creates: /etc/kubernetes/admin.conf`로 이미 완료된 노드는 스킵)

**dpkg lock 에러로 설치 실패**
- **증상**: 앤서블 패키지 설치 태스크 중 에러 발생
- **원인**: VM 부팅 직후 unattended-upgrades가 apt lock 점유
- **해결**: 플레이북 재실행하면 자동 대기 후 해결
