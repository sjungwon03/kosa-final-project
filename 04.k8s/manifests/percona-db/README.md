# Percona DB (Operator + PXC)

Percona Helm chart(`pxc-operator`, `pxc-db`) 기반으로 MySQL 호환 클러스터를 배포합니다.

## 배포 토폴로지
- PXC: 3 Pods
- HAProxy: 3 Pods
- 스케줄링 노드 제한: `k8s-worker-01`, `k8s-worker-02`, `k8s-worker-03`
- PodAntiAffinity로 동일 역할 Pod가 서로 다른 노드에 분산

## 진입점
- Read/Write 진입점: `percona-db-pxc-db-haproxy.devops.svc.cluster.local:3306`
- 외부 진입점: `LoadBalancer` 타입 HAProxy 서비스

## 배포
```bash
./04.k8s/scripts/deploy-devops.sh install percona-db
```

## 확인
```bash
kubectl -n devops get pods | grep percona-db
kubectl -n devops get svc | grep percona-db
kubectl -n devops get pods -o wide | grep -E 'pxc|haproxy'
```
