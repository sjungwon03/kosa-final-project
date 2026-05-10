#!/bin/bash

# MySQL MHA Manager 배포 스크립트

set -e

# 환경 변수
NAMESPACE="kosa"
MYSQL_REPLICATION_USER="replication"
MYSQL_REPLICATION_PASSWORD="password"

echo "MySQL MHA Manager 배포 시작..."

# MySQL MHA Manager ConfigMap 생성
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mha-manager-config
  namespace: ${NAMESPACE}
data:
  app1.cnf: |
    [server default]
    user=${MYSQL_REPLICATION_USER}
    password=${MYSQL_REPLICATION_PASSWORD}
    manager_workdir=/var/log/masterha/app1
    manager_log=/var/log/masterha/app1/manager.log
    remote_workdir=/var/log/masterha/app1

    [server1]
    hostname=mysql-master-0.mysql-master.${NAMESPACE}.svc.cluster.local

    [server2]
    hostname=mysql-slave-0.mysql-slave.${NAMESPACE}.svc.cluster.local

    [server3]
    hostname=mysql-slave-1.mysql-slave.${NAMESPACE}.svc.cluster.local
EOF

# MySQL MHA Manager Deployment 생성
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mha-manager
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mha-manager
  template:
    metadata:
      labels:
        app: mha-manager
    spec:
      containers:
      - name: mha-manager
        image: docker.io/debarchan/mha4mysql-manager:0.58
        command:
        - /bin/bash
        - -c
        - |
          mkdir -p /var/log/masterha/app1
          cp /etc/mha/app1.cnf /etc/masterha/default.cnf
          sleep 60
          masterha_manager --conf=/etc/masterha/default.cnf
        volumeMounts:
        - name: mha-config
          mountPath: /etc/mha
        - name: mha-log
          mountPath: /var/log/masterha
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: mha-config
        configMap:
          name: mha-manager-config
      - name: mha-log
        emptyDir: {}
EOF

echo "MySQL MHA Manager 배포 완료!"
echo "MHA Manager 로그 확인: kubectl logs -f deployment/mha-manager -n ${NAMESPACE}"