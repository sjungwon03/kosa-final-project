# GitLab

**스택**
- GitLab CE: Git 저장소 + CI/CD 플랫폼 (K8s Operator 방식)
- GitLab Runner: 파이프라인 실행 (외부 VM)
- Harbor: 컨테이너 레지스트리 (GitLab Registry 비활성화, Harbor 사용)

**구성**
- GitLab (K8s): gitlab.mgmt.local → MetalLB 172.16.30.203
- GitLab Operator: `gitlab-system` 네임스페이스
- GitLab 리소스: `gitlab` 네임스페이스
- GitLab Runner VM: cicd-01 (172.16.30.55, 8GB)
- 저장소 용도: 웹앱 CI/CD + 인프라 IaC (Terraform/Ansible)

**노드 배치**: k8s-worker-plat (Harbor 동일 노드)

---

## GitLab 구축 (설치)

> 최초 1회 실행

**사전 조건**
- MetalLB 정상 동작 (`kubectl get pods -n metallb-system`)
- rbd-storage StorageClass 존재 (`kubectl get storageclass`)
- master-01 인터넷 접근 가능 (Operator 매니페스트 다운로드)
- cert-manager 설치 완료 (GitLab Operator 내부 webhook 인증서 필요)

**1. cert-manager 설치 (master-01)**

GitLab Operator가 내부 webhook TLS 인증서 관리에 cert-manager를 사용함. 없으면 Operator 설치 시 `Issuer CRD not found` 오류 발생

```bash
# [master-01]
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml

# webhook 준비 대기 (약 1~2분 — 너무 빨리 재시도하면 x509 인증서 오류)
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=300s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=300s
kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=120s
```

**2. 매니페스트 전송 (로컬)**
```bash
# [로컬]
scp -r 04.k8s/manifests/gitlab-operator kosa@172.16.30.31:~/k8s/manifests/
scp 04.k8s/scripts/deploy-devops.sh kosa@172.16.30.31:~/k8s/scripts/deploy-devops.sh
```

**3. GitLab Operator 설치 (master-01)**
```bash
# [master-01]
GL_OPERATOR_VERSION=2.9.0 ./scripts/deploy-devops.sh install gitlab-operator
```

설치 순서:
1. `gitlab` 네임스페이스 생성
2. GitLab Operator 매니페스트 적용 → `gitlab-system`에 operator 배포
3. Operator 준비 대기 (`gitlab-system/gitlab-controller-manager`)
4. GitLab CR 적용 → webservice, gitaly, postgresql, redis 등 파드 기동

**4. Operator 및 CR 상태 확인**
```bash
# [master-01] Operator 확인
kubectl get pods -n gitlab-system

# CR 처리 상태 확인 (이상 없으면 파드 생성 시작)
kubectl describe gitlab gitlab -n gitlab | tail -30
kubectl logs -n gitlab-system deployment/gitlab-controller-manager --tail=30
```

**5. 기동 확인 (master-01)**
```bash
# [master-01] 전체 Running까지 최대 30분
watch kubectl get pods -n gitlab

# LoadBalancer IP 확인 (172.16.30.203)
kubectl get svc -n gitlab

# 브라우저 접속
# http://gitlab.mgmt.local  (DNS: dns_servers.yml → .203)
# http://172.16.30.203      (DNS 없을 때)
```

**6. 초기 root 비밀번호 확인**
```bash
# [master-01]
kubectl get secret -n gitlab gitlab-gitlab-initial-root-password \
  -o jsonpath='{.data.password}' | base64 -d
```

**7. DNS 등록 확인 (컨트롤 노드)**

`dns_servers.yml`에 이미 추가됨. 플레이북 재실행으로 적용:
```bash
# [컨트롤 노드]
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/dns.yml

# 검증
nslookup gitlab.mgmt.local 172.16.30.11
```

---

## GitLab Runner 구성 (cicd-01)

**1. GitLab Runner 설치**
```bash
# [cicd-01: 172.16.30.55]
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install gitlab-runner -y
```

**2. Runner 등록**
```bash
# GitLab 웹: Settings > CI/CD > Runners > New project runner
# Registration token 복사 후:
sudo gitlab-runner register \
  --url "http://gitlab.mgmt.local" \
  --registration-token "<TOKEN>" \
  --executor "shell" \
  --description "cicd-01-shell-runner" \
  --tag-list "shell,terraform,ansible"
```

**3. Runner 상태 확인**
```bash
sudo gitlab-runner status
sudo gitlab-runner list
```

---

## GitLab 운영

**파이프라인 용도별 Runner 태그**

| 태그 | 용도 |
|------|------|
| `shell` | 범용 |
| `terraform` | Terraform IaC 파이프라인 |
| `ansible` | Ansible 플레이북 파이프라인 |

**Harbor 연동 (컨테이너 이미지 push)**
```yaml
# .gitlab-ci.yml 예시
build:
  script:
    - docker login harbor.mgmt.local -u admin -p <password>
    - docker build -t harbor.mgmt.local/<project>/<image>:<tag> .
    - docker push harbor.mgmt.local/<project>/<image>:<tag>
```

**ArgoCD 연동 (GitOps 배포)**
- GitLab 저장소를 ArgoCD의 소스 레포로 등록
- ArgoCD → Settings > Repositories > Connect Repo

---

## 트러블슈팅

**Operator 설치 시 `Issuer CRD not found`**
- 원인: cert-manager 미설치 — GitLab Operator 매니페스트에 cert-manager Issuer 리소스 포함
- 해결: cert-manager 먼저 설치 후 재시도

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=120s
GL_OPERATOR_VERSION=2.9.0 ./scripts/deploy-devops.sh install gitlab-operator
```

**Operator 설치 시 `x509: certificate signed by unknown authority`**
- 원인: cert-manager 설치 직후 webhook TLS 초기화 완료 전에 재시도
- 해결: `kubectl wait --for=condition=ready pod -l app=webhook -n cert-manager` 후 재시도

**`deployment/gitlab-controller-manager not found`**
- 원인: deploy-devops.sh의 rollout status가 `gitlab` 네임스페이스를 봄 (실제는 `gitlab-system`)
- 확인: `kubectl get pods -n gitlab-system`
- Operator pod이 있으면 CR만 수동 적용:

```bash
kubectl rollout status deployment/gitlab-controller-manager -n gitlab-system --timeout=300s
kubectl apply -f ~/k8s/manifests/gitlab-operator/gitlab-cr.yaml
```

**CR 적용 후 `No resources found in gitlab namespace`**
- 원인: Operator가 CR을 처리하지 못한 상태 — Operator 로그 확인

```bash
kubectl logs -n gitlab-system deployment/gitlab-controller-manager --tail=50
kubectl describe gitlab gitlab -n gitlab | grep -A20 "Status:"
```

**webservice 파드 기동 지연**
- 원인: gitaly, postgresql, redis 의존성 준비 전에 시작 시도
- 해결: 자동 재시도 — 최대 30분 소요

```bash
kubectl describe pod -n gitlab <webservice-pod> | grep -A10 "Events:"
```

**Runner 등록 실패**
- cicd-01에서 gitlab.mgmt.local DNS 해석 가능 여부 확인

```bash
# [cicd-01]
nslookup gitlab.mgmt.local
curl -I http://gitlab.mgmt.local
```
