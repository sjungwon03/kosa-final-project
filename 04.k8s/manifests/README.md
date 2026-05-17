# DNS 등록 정보

MetalLB IP Pool (172.16.30.200-172.16.30.210)에서 서비스 LoadBalancer IP를 DNS 서버에 등록합니다.

| 서비스 | 도메인 | 설명 |
|--------|--------|------|
| Harbor | harbor.mgmt.local | 컨테이너 레지스트리 |
| Gitea  | gitea.mgmt.local  | Git 저장소 + Actions |
| ArgoCD | argocd.mgmt.local | GitOps 도구 |

## DNS 등록 방법

1. 서비스별 LoadBalancer IP 확인:

```bash
kubectl get svc -n devops
```

2. DNS 서버에 A 레코드 추가:

```text
harbor.mgmt.local    IN A    <HARBOR_LB_IP>
gitea.mgmt.local     IN A    <GITEA_LB_IP>
argocd.mgmt.local    IN A    <ARGOCD_LB_IP>
```

## 접속 정보

- Harbor: `http://harbor.mgmt.local`
- Gitea: `http://gitea.mgmt.local`
- ArgoCD: `http://argocd.mgmt.local`

## Percona DB 접속 정보

- 내부 접속: `percona-db-pxc-db-haproxy.devops.svc.cluster.local:3306`
- 외부 접속: `kubectl get svc -n devops | grep percona-db`
