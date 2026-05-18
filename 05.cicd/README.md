# CICD

## 구성 개요

CICD는 목적에 따라 두 레이어로 분리됨

| 레이어 | 컴포넌트 | 위치 | 목적 |
|---|---|---|---|
| 인프라 CI | Gitea + act_runner | 외부 VM (172.16.30.55) | Terraform/Ansible 자동화, Nexus 미러링 |
| 앱 CI/CD | GitLab + ArgoCD | K8s 내부 (팀원 담당) | 서비스 빌드·테스트·K8s 자동 배포 |

**분리 이유**: K8s가 자신의 인프라를 관리하면 순환 의존성(Ouroboros) 발생
— K8s 장애 시 복구 수단 자체가 K8s 안에 있으면 복구 불가

## 인프라 CI 역할 (이 팀 담당)

```text
Gitea (VM .55)
    │ push
    ▼
act_runner (VM .55)
    ├── Terraform apply  → VM 프로비저닝
    ├── Ansible playbook → 서비스 구성
    └── Nexus 미러링     → 패키지·이미지 인터넷 → 내부 복사
```

## 폐쇄망 전환 전/후

| 구간 | act_runner 동작 |
|---|---|
| 인터넷 단계 | 인터넷에서 직접 패키지·이미지 pull → Nexus push |
| 폐쇄망 단계 | Nexus만 참조 — 동일 파이프라인 그대로 동작 |

## 배포

```bash
ANSIBLE_CONFIG=~/workspace/ansible/ansible.cfg \
  ansible-playbook \
  -i ~/workspace/ansible/inventories/prod/hosts \
  ~/workspace/ansible/playbooks/cicd.yml
```

> 앱 CI/CD (GitLab + ArgoCD)는 `06.argocd/` 참조 (팀원 담당)
