# Kubernetes

- Kubernetes 클러스터 구성 및 내부 리소스(Manifest/Helm) 관리
- Helm chart 기반으로 DevOps 서비스 배포

> `MetalLB`와 `Ceph CSI/StorageClass`는 `03.ansible/workspace/playbooks/k8s.yml`에서 관리함

**파이프라인 (실행 순서)**

| 순서 | 폴더 | 내용 | 실행 위치 |
|---|---|---|---|
| 1 | 00.scripts | 베이스 템플릿(9000) 생성 | Proxmox 호스트 |
| 2 | 01.packer | 공통 템플릿(9003, 9005) 생성 | 빌드 서버 |
| 3 | 03.ansible | 컨트롤 노드 VM 생성 | Proxmox 호스트 |
| 4 | 02.terraform | VM 프로비저닝 | 컨트롤 노드 |
| 5 | 03.ansible | Ansible 플레이북 실행 (K8s 조인) | 컨트롤 노드 |
| 6 | **04.k8s** | **K8s 클러스터 리소스 관리** | **컨트롤 노드** |


## 구조

```text
04.k8s/
├── manifests/
│   ├── metallb/             # MetalLB LoadBalancer
│   ├── storage/             # Ceph RBD StorageClass/Secret
│   ├── harbor/              # Harbor 컨테이너 레지스트리 (Helm)
│   ├── gitea/               # Gitea + Actions Runner (Helm)
│   ├── percona-db/          # Percona Operator + PXC (Helm)
│   ├── argocd/              # ArgoCD GitOps (Helm)
│   ├── gitlab-operator/     # GitLab Operator + GitLab CR (Manifest)
│   ├── eks/                 # EKS 클라우드 버스팅용
│   └── namespace.yaml
└── scripts/
    ├── deploy-devops.sh    # Harbor, Gitea, Percona DB, ArgoCD
    ├── upgrade-devops.sh   # 위 서비스 업그레이드
    └── install-gitlab.sh   # GitLab Operator 전용 (cert-manager 선행 필요)
```

## 배포

### 1단계: MetalLB + Ceph CSI 설치 (컨트롤 노드)

`deploy-devops.sh` 실행 전 StorageClass와 MetalLB가 없으면 실행

```bash
# [컨트롤 노드]
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/k8s.yml
```

### 2단계: 설치 확인 (k8s 마스터)

```bash
# [master-01] StorageClass 및 MetalLB 파드 확인
kubectl get storageclass
kubectl get pods -n metallb-system

# [master-01] 전체 네임스페이스 파드 현황 (kube-system 정상 기준: 약 20개)
kubectl get pods -A

# [master-01] 노드 상세 (CPU/메모리 할당 현황)
kubectl describe nodes | grep -A5 "Allocated resources"
```

### 3단계: DevOps 서비스 배포 (k8s 마스터)

```bash
# [로컬] master-01로 전체 전송
scp -r 04.k8s/scripts 04.k8s/manifests kosa@172.16.30.31:~/k8s/

# [로컬] master-01로 개별 전송
scp -r 04.k8s/manifests/percona-db kosa@172.16.30.31:~/k8s/manifests/

# [master-01] 전체 설치 (Harbor + Gitea + Percona DB + ArgoCD) — 이미지 풀 포함 20분 소요
./scripts/deploy-devops.sh install

# [master-01] 개별 설치
./scripts/deploy-devops.sh install harbor
./scripts/deploy-devops.sh install gitea
./scripts/deploy-devops.sh install percona-db
./scripts/deploy-devops.sh install argocd

# GitLab은 별도 스크립트 사용 (cert-manager 선행 필요)
GL_OPERATOR_VERSION=2.9.0 ./scripts/install-gitlab.sh install

# [master-01] 개별 삭제
./scripts/deploy-devops.sh uninstall percona-db
```

### 4단계: 설치 확인 (k8s 마스터)

```bash
# [master-01] 파드 상태 확인 (전체 Running까지 약 20분 ~ 30분)
kubectl get pods -n harbor | grep redis
kubectl get pods -n harbor
kubectl get pods -n argocd
kubectl get pods -n gitea
kubectl get pods -n gitlab
kubectl get pods -n percona-db

# [master-01] 상태 모니터링
watch kubectl get pods -n percona-db

# [master-01] LoadBalancer IP 확인 (172.16.30.200-202 범위)
kubectl get svc -n harbor
kubectl get svc -n argocd
kubectl get svc -n gitea
kubectl get svc -n gitlab
kubectl get svc -n percona-db
```

## 업그레이드

> values.yaml 변경 또는 차트 버전 업 적용 시 사용

```bash
# [master-01] 전체 업그레이드
./scripts/upgrade-devops.sh

# [master-01] 개별 업그레이드
./scripts/upgrade-devops.sh harbor
./scripts/upgrade-devops.sh gitea
./scripts/upgrade-devops.sh percona-db
./scripts/upgrade-devops.sh argocd
GL_OPERATOR_VERSION=2.9.0 ./scripts/install-gitlab.sh install
```

---

## Percona DB 진입점

```bash
# 클러스터 내부
percona-db-pxc-db-haproxy.percona-db.svc.cluster.local:3306

# 클러스터 외부
kubectl -n percona-db get svc | grep haproxy
```

---

## DNS 등록

- DNS는 Ansible `dns_servers.yml`의 `dns_records`로 관리 — [01.dns.md](../03.ansible/03.runbooks/01.dns.md) 참조
- IP는 MetalLB 풀에서 미리 지정 (harbor=.200, gitea=.201, argocd=.202)

MetalLB IP 확인 후 `dns_servers.yml`에 반영되어 있지 않으면 추가:
```bash
# [컨트롤 노드]
vi ~/workspace/ansible/inventories/prod/group_vars/dns_servers.yml
```

```yaml
dns_records:
  - { name: "harbor",  ip: "172.16.30.200", domain: "mgmt.local" }
  - { name: "gitea",   ip: "172.16.30.201", domain: "mgmt.local" }
  - { name: "argocd",  ip: "172.16.30.202", domain: "mgmt.local" }
```

```bash
# [컨트롤 노드] DNS 플레이북 재실행
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/dns.yml
```

## 기본 계정 정보

| 서비스 | DNS | 계정 |
|--------|-----|------|
| Harbor | harbor.mgmt.local | admin / values.yaml에 설정된 값 |
| Gitea | gitea.mgmt.local | kosa / values.yaml에 설정된 값 |
| Percona DB | 내부/외부 Service | root / values.yaml에 설정된 값 |
| ArgoCD | argocd.mgmt.local | admin |

---

## 트러블슈팅

**harbor-core CrashLoopBackOff**
- 원인: harbor-redis 미기동 상태에서 core가 먼저 시작됨
- 해결: harbor-redis Running 후 자동 복구 — 기다리면 됨

```bash
kubectl get pods -n harbor | grep redis
kubectl logs -n harbor <harbor-core-pod>
```

**gitea ImagePullBackOff — bitnami 이미지 not found**
- 원인: gitea chart 10.x가 docker.io/bitnami 이미지 참조하는데 해당 태그 docker.io에서 삭제됨
- 해결: gitea chart 12.x 이상으로 버전 업 (Chart.yaml dependency version 수정 후 `helm dependency update`)

```bash
kubectl describe pod -n gitea <pod> | grep -A5 "Events:"
# "not found" 에러 확인 후 Chart.yaml 버전 수정
helm dependency update ~/k8s/manifests/gitea/
./scripts/deploy-devops.sh uninstall gitea
./scripts/deploy-devops.sh install gitea
```

**percona pxc Pending — StorageClass 불일치**
- 원인: `values.yaml`의 `storageClass`가 실제 StorageClass 이름과 다름 (`ceph-rbd` ≠ `rbd-storage`)
- 해결: `values.yaml`의 `storageClass: rbd-storage` 수정 후 재배포

```bash
kubectl get pvc -n percona-db
kubectl describe pvc -n percona-db <pvc-name> | grep StorageClass
```

**percona pxc-db CR 미생성 (operator만 뜨고 pxc 파드 없음)**
- 원인: `pxc-operator`와 `pxc-db`를 동시 설치 시 CRD 등록 전에 CR 적용 시도 → silent fail
- 해결: `deploy-devops.sh`에서 자동 처리 (operator rollout 대기 후 helm upgrade 재적용)
- 수동 복구 시: operator Running 확인 후 `helm upgrade` 실행

```bash
kubectl get pxc -n percona-db
kubectl rollout status deployment/percona-db-pxc-operator -n percona-db
helm upgrade percona-db ~/k8s/manifests/percona-db \
  -n percona-db -f ~/k8s/manifests/percona-db/values.yaml --timeout 600s
```

**Ansible MetalLB/Ceph CSI 스킵 (skipped=28)**
- 원인: `inventories/prod/group_vars/all.yml` 누락 시 `metallb_enabled`, `ceph_csi_enabled` 기본값 false 적용
- 해결: `03.ansible/workspace/inventories/prod/group_vars/all.yml` 파일 존재 확인 후 재실행

```bash
# [컨트롤 노드]
ls ~/workspace/ansible/inventories/prod/group_vars/all.yml
kubectl get storageclass      # rbd-storage 확인
kubectl get pods -n metallb-system
```

---

## [TODO] 고도화 로드맵

### Phase 1: GitOps Auto-Provisioning
- **장애 복구 자동화**: Gitea Actions Webhook 연동
- **스케일 아웃**: 부하 발생 시 컨트롤 노드에서 `terraform apply` → `ansible-playbook` 자동 트리거 구축

### Phase 2: Manifest 구조화 및 CD 연동
- **ArgoCD 연동**: `06.argocd`와 연동하여 GitOps 배포 체계 완성
- **리소스 선언**: 모니터링 에이전트, Vault Injector, Ingress 룰 등 모든 리소스의 YAML/Helm 관리

### Phase 3: Persistent Storage (CSI)
- **Ceph CSI 구성**: Proxmox Ceph(rbd-storage)와 K8s StorageClass 연동
- **동적 볼륨 할당**: PVC를 통한 파드 영구 데이터 저장 환경 구축
