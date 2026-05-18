# Terraform 배포 성능 최적화

더 빠른 배포와 구성을 위한 방법 정리

---

## 현재 병목 원인

- Ceph RBD 락: 템플릿(9003, 9005) 클론 시 동시 접근 불가함
- `-parallelism=1` 강제 적용으로 VM이 순차 생성됨 (VM당 약 2분 소요)

---

## 방법 1: parallelism 상향 테스트

클론 대상이 **서로 다른 Proxmox 노드**(`kosa21`, `kosa22`, `kosa23`)이면 RBD 락이 겹치지 않을 가능성 있음

```bash
terraform apply -var-file=tfvars/k8s-master.tfvars -parallelism=3
```

> 실패 시 `state lock` 오류 발생하므로 재시도하면 됨
> 안정적으로 동작하면 `02-run.sh`의 기본값을 상향 조정함

---

## 방법 2: 노드별 병렬 실행 (-target)

터미널 여러 개에서 각 노드 대상 VM만 `-target`으로 동시 실행함

```bash
# 터미널 1 (kosa21)
./02-run.sh prod apply k8s-master k8s-master-01

# 터미널 2 (kosa22)
./02-run.sh prod apply k8s-master k8s-master-02

# 터미널 3 (kosa23)
./02-run.sh prod apply k8s-master k8s-master-03
```

- 각 노드에서 독립적으로 클론이 진행되므로 RBD 락 충돌 없음
- state 파일은 공유하므로 동시에 같은 역할 파일을 apply하면 충돌 가능하여 역할별로 분리해서 실행함

---

## [TODO] 방법 3: 링크드 클론(Linked Clone) 사용 고려 (테스트 환경)

현재 `main.tf`의 클론 구성은 `full = true`가 하드코딩되어 완전한 디스크 복제(풀 클론)를 수행함
추후 테스트 환경 배포 속도 향상을 위해 이를 변수화(`var.full_clone`)하여 링크드 클론을 적용하는 방안을 고려함
링크드 클론은 디스크 복사가 아닌 참조만 생성하므로 **수 초 내에 VM 생성이 완료**됨

- **장점**: 압도적으로 빠른 생성 속도
- **단점**: 원본 템플릿 삭제 불가하며 디스크 I/O (CoW) 오버헤드로 인해 프로덕션(특히 etcd 등 I/O 민감 워크로드)에서는 권장하지 않음
- **구현 과제**: `variables.tf` 및 `main.tf`를 수정하여 환경별(prod/test) 분기 처리 필요함

---

## 방법 4: 워커 풀 사전 프로비저닝 (운영 환경 추천)

미리 VM을 생성해두고 클러스터에 조인하지 않은 상태로 대기함

- 장애 발생 시 VM 생성 시간(2분) 없이 Ansible 조인만 수행하여 즉시 투입 가능함
- `k8s-worker-pool.tfvars`로 관리하며 `k8s-worker.tfvars`와 별도 상태 유지함

```bash
# 풀 VM 사전 생성
./02-run.sh prod apply k8s-worker-pool

# 장애 발생 시 즉시 조인 (Ansible만 실행)
ansible-playbook playbooks/ops/add-worker.yml --limit 172.16.30.48
```

---

## 실행 시간 스탬프 (Time Tracking)

`02-run.sh` 스크립트를 통해 Terraform 배포를 실행하면 작업 완료 후 최종적으로 **소요 시간**이 출력됨
이를 통해 성능 최적화(parallelism 조정, 링크드 클론 등) 적용 전/후의 배포 시간을 직접 비교할 수 있음

```text
[2026-05-14 19:20:00] start terraform apply for k8s-master in prod
...
[2026-05-14 19:22:05] done in 2m 5s
```

---

## 추천 전략

| 우선순위 | 환경 | 추천 방법 | 효과 |
|---|---|---|---|
| 1 | Test | `full_clone = false` | 수 초 내 즉시 배포 |
| 2 | Prod | parallelism 상향 (`-parallelism=3`) | 병렬 배포로 전체 시간 단축 |
| 3 | All | **K8s Master 로컬 스토리지 사용** | **etcd I/O 성능 및 클러스터 안정성 확보** |
| 4 | Prod | 워커 풀 사전 프로비저닝 | 장애 복구 시간 단축 |

---

## 방법 5: etcd 성능 최적화 (Local LVM 사용)

네트워크 스토리지(Ceph RBD)는 데이터 일관성을 위해 네트워크를 타므로 etcd의 쓰기 지연(Fsync)에 민감한 영향을 줌
이를 해결하기 위해 K8s 마스터 노드(etcd 구동 노드)는 **로컬 LVM**을 사용하도록 구성됨

- **대상**: `k8s-master-01~03`
- **설정**: `tfvars` 파일 내 `datastore_id = "local-lvm"` 지정함
- **효과**: 네트워크 레이턴시 제거를 통한 etcd `wal_fsync` 지연 방지 및 클러스터 안정성 향상
