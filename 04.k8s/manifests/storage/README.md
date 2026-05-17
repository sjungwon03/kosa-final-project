# Ceph Storage (RBD)

Harbor, Gitea, ArgoCD PVC가 Ceph RBD를 사용하도록 `rbd-storage` StorageClass를 생성합니다.

## 사전 조건
- 클러스터에 Ceph CSI 드라이버(`rbd.csi.ceph.com`)가 설치되어 있어야 합니다.
- Ceph 클러스터 FSID, 사용자 ID/Key를 알고 있어야 합니다.

## 설정
1. `01-ceph-secret.yaml`의 값을 수정합니다.
- `userID`
- `userKey`
2. `02-rbd-storageclass.yaml`의 `clusterID`를 수정합니다.

## 적용
```bash
kubectl apply -f 04.k8s/manifests/storage/
```

## 확인
```bash
kubectl get sc rbd-storage
kubectl -n kube-system get secret ceph-csi-rbd-secret
```
