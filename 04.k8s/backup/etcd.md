# etcd 백업 및 복구

> Ceph 자체가 손상될 경우 데이터 복구가 불가능하므로 Ceph와 별도 서버인 MinIO에 etcd 스냅샷을 저장해 장애 도메인을 분리한 백업 구성임

- 대상: K8s 컨트롤 플레인 etcd
- 저장소: MinIO (`minio/k8s-backup/etcd/`)
- 실행 위치: master-01 (172.16.30.31)


## 사전 준비

**mc 설치**
```bash
# [master-01]
curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc && sudo mv mc /usr/local/bin/

mc alias set minio http://172.16.30.70:9000 <ACCESS_KEY> <SECRET_KEY>
mc mb minio/k8s-backup
```


## 백업

```bash
# [master-01]
SNAP=/tmp/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db

ETCDCTL_API=3 etcdctl snapshot save "$SNAP" \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

mc cp "$SNAP" minio/k8s-backup/etcd/
rm -f "$SNAP"
```

**확인**
```bash
# 스냅샷 상태 확인
ETCDCTL_API=3 etcdctl snapshot status "$SNAP" --write-out=table

# MinIO 업로드 확인
mc ls minio/k8s-backup/etcd/ | tail -5
```


## 복구

> 클러스터 완전 장애 시 사용 (모든 마스터 노드에서 etcd 중단 후 진행)

```bash
# [master-01] MinIO에서 스냅샷 다운로드
mc cp minio/k8s-backup/etcd/<파일명>.db /tmp/etcd-restore.db

# etcd 서비스 중단 (전체 마스터 노드)
sudo systemctl stop etcd

# 스냅샷 복구
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-restore.db \
  --data-dir=/var/lib/etcd-restore \
  --name=master-01 \
  --initial-cluster="master-01=https://172.16.30.31:2380,master-02=https://172.16.30.32:2380,master-03=https://172.16.30.33:2380" \
  --initial-cluster-token=etcd-cluster \
  --initial-advertise-peer-urls=https://172.16.30.31:2380

# 기존 데이터 교체
sudo mv /var/lib/etcd /var/lib/etcd.bak
sudo mv /var/lib/etcd-restore /var/lib/etcd

# etcd 재시작
sudo systemctl start etcd

# 클러스터 상태 확인
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```


## 자동화 (cron)

```bash
# [master-01] crontab -e
0 2 * * * /usr/local/bin/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1
```

`/usr/local/bin/etcd-backup.sh`:
```bash
#!/bin/bash
SNAP=/tmp/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db
ETCDCTL_API=3 etcdctl snapshot save "$SNAP" \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
mc cp "$SNAP" minio/k8s-backup/etcd/
rm -f "$SNAP"
```
