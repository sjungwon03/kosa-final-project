# DNS 등록 정보

MetalLB IP Pool (172.16.30.200-172.16.30.210)에서 HAProxy Ingress Controller LoadBalancer IP를 DNS 서버에 등록:

| 서비스            | 도메인              | 설명              |
|------------------|--------------------|--------------------|
| Harbor           | harbor.mgmt.local  | 컨테이너 레지스트리 |
| GitLab           | gitlab.mgmt.local  | Git 저장소         |
| ArgoCD           | argocd.mgmt.local  | GitOps 도구        |

## DNS 등록 방법

1. MetalLB에서 할당된 HAProxy Ingress IP 확인:
   ```bash
   kubectl get svc haproxy-ingress-controller -n ingress-controller
   ```

2. DNS 서버에 A 레코드 추가 (MetalLB IP):
   ```
   harbor.mgmt.local    IN A    <METALLB_IP>
   gitlab.mgmt.local    IN A    <METALLB_IP>
   argocd.mgmt.local    IN A    <METALLB_IP>
   ```

## 접속 정보

- Harbor: http://harbor.mgmt.local (admin/Kosa1004)
- GitLab: http://gitlab.mgmt.local (root/GitLabRootPassword123)
- ArgoCD: http://argocd.mgmt.local (admin/ArgoCDAdmin123)