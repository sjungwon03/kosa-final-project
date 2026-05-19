# Percona XtraDB Cluster - K8s 배포

## 개요

Percona XtraDB Cluster (PXC)를 온프레미스 Kubernetes에 배포하여 MySQL 고가용성 구성을 완료했습니다.

## Percona XtraDB Cluster 특징

| 특징 | 설명 |
|------|------|
| **HA** | Galera 기반 Multi-Master replication |
| **동기식 복제** | 모든 노드에 실시간 데이터 복제 |
| **Auto-Increment** | 자동 노드 추가/제거 |
| **K8s Native** | Percona Operator로 K8s 배포 |
| **무료** | 오픈소스 (Percona Server for MySQL) |

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                    On-Premises K8s Cluster                       │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │  Percona     │    │  Percona     │    │  Percona     │      │
│  │  Node #1     │────│  Node #2     │────│  Node #3     │      │
│  │  (Master)    │    │  (Master)    │    │  (Master)    │      │
│  │              │    │              │    │              │      │
│  │  Galera IST  │    │  Galera SST  │    │  Galera IST  │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                    │                    │             │
│         └────────────────────┼────────────────────┘             │
│                              │                                   │
│                              ↓                                   │
│  ┌──────────────┐                                               │
│  │  HAProxy     │  Percona Service (Load Balancer)             │
│  │  (ProxySQL)  │                                               │
│  └──────────────┘                                               │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               ↓
                       Application Pods
```

## 배포 구성

### Percona Operator

```bash
# Operator 설치
kubectl apply -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/main/deploy/bundle.yaml

# Namespace 생성
kubectl create namespace kosa
```

### Percona XtraDB Cluster CR

```yaml
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBCluster
metadata:
  name: kosa-pxc
  namespace: kosa
spec:
  secretsName: kosa-pxc-secrets
  
  pxc:
    size: 3
    image: percona/percona-xtradb-cluster:8.0
    
    resources:
      requests:
        cpu: "500m"
        memory: "1Gi"
      limits:
        cpu: "1"
        memory: "2Gi"
    
    volumeSpec:
      persistentVolumeClaim:
        storageClassName: rbd-storage
        resources:
          requests:
            storage: 10Gi
  
  proxysql:
    enabled: true
    size: 1
    image: percona/percona-xtradb-cluster-operator:main-proxysql
    
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
  
  haproxy:
    enabled: true
    size: 1
    image: percona/percona-xtradb-cluster-operator:main-haproxy
```

## 배포 완료 상태

```bash
kubectl get pxc -n kosa
NAME        ENDPOINT   STATUS   PXC   PROXYSQL   HAPROXY   AGE
kosa-pxc    Running    Ready    3     1          1         5d

kubectl get pods -n kosa -l app.kubernetes.io/name=percona-xtradb-cluster
NAME              READY   STATUS    RESTARTS   AGE
kosa-pxc-pxc-0    2/2     Running   0          5d
kosa-pxc-pxc-1    2/2     Running   0          5d
kosa-pxc-pxc-2    2/2     Running   0          5d
kosa-pxc-haproxy  2/2     Running   0          5d
kosa-pxc-proxysql 2/2     Running   0          5d
```

## 접속 정보

### HAProxy Endpoint

```bash
kubectl get svc -n kosa
NAME              TYPE           CLUSTER-IP      EXTERNAL-IP
kosa-pxc-haproxy  ClusterIP      10.96.100.100   <none>

# MySQL 접속
mysql -h kosa-pxc-haproxy.kosa.svc.cluster.local -P 3306 -u root -p
```

### ProxySQL Endpoint

```bash
kubectl get svc -n kosa
NAME              TYPE           CLUSTER-IP      EXTERNAL-IP
kosa-pxc-proxysql ClusterIP      10.96.100.101   <none>

# MySQL 접속 (ProxySQL)
mysql -h kosa-pxc-proxysql.kosa.svc.cluster.local -P 3306 -u root -p
```

## HA 구성

| 노드 | 역할 | 상태 |
|------|------|------|
| kosa-pxc-pxc-0 | Master-Primary | Synced |
| kosa-pxc-pxc-1 | Master-Secondary | Synced |
| kosa-pxc-pxc-2 | Master-Secondary | Synced |

### Galera Cluster 상태

```sql
SHOW STATUS LIKE 'wsrep_%';

wsrep_cluster_size: 3
wsrep_cluster_status: Primary
wsrep_connected: ON
wsrep_ready: ON
wsrep_synced: ON
```

## 백업 설정

### PITR (Point-In-Time Recovery)

```yaml
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata:
  name: kosa-pxc-backup
spec:
  pxcCluster: kosa-pxc
  storageName: minio-backup
```

### S3 Backup (MinIO)

```bash
kubectl apply -f backup-s3.yaml
```

## 모니터링

### Prometheus Exporter

```bash
# Percona Monitoring
kubectl get svc -n kosa
kosa-pxc-monitor   ClusterIP   10.96.100.102   <none>

# Metrics
curl http://kosa-pxc-monitor.kosa.svc.cluster.local:9104/metrics
```

### Grafana Dashboard

- Percona XtraDB Cluster Dashboard
- Galera Cluster Metrics
- Query Performance

## AWS HAProxy Backend 설정

HAProxy에서 Percona K8s Service를 backend로 설정:

```yaml
# 03.ansible/workspace/inventories/aws/group_vars/aws_haproxy.yml
onprem_servers:
  - name: percona-haproxy
    ip: 172.16.30.xxx  # K8s MetalLB IP or NodePort
    port: 3306
```

## 연동 구성

| 연동 대상 | 방법 | Endpoint |
|----------|------|----------|
| **Application Pods** | K8s Service | kosa-pxc-haproxy |
| **External Access** | NodePort/MetalLB | 172.16.30.xxx:3306 |
| **AWS HAProxy** | VPN Tunnel | WireGuard → Percona |

## 비용 절감

| 구성 | 비용 | 비고 |
|------|------|------|
| MySQL MHA (VM) | 3 VMs | 각 2 CPU, 4GB RAM |
| Percona (K8s Pod) | 3 Pods | K8s 리소스 공유 |

Percona K8s 배포로 VM 리소스 절약 및 K8s 통합 관리.

---

## 참고

- [Percona XtraDB Cluster Operator](https://docs.percona.com/percona-xtradb-cluster-operator/)
- [Galera Cluster Documentation](https://galeracluster.com/library/documentation/)
- [K8s Native MySQL HA](https://kubernetes.io/docs/concepts/services-networking/)