# GitLab 사용 가이드

설치 문서: `04.k8s/manifests/gitlab-operator/README.md`

---

## 초기 접속 및 관리자 설정

**접속**
- URL: `http://gitlab.mgmt.local` (또는 `http://172.16.30.203`)
- 계정: `root` / 초기 비밀번호 확인:

```bash
# [master-01]
kubectl get secret -n gitlab-system gitlab-gitlab-initial-root-password \
  -o jsonpath='{.data.password}' | base64 -d
```

**초기 비밀번호 변경**
- 우상단 아바타 > Edit profile > Password

---

## 사용자 관리

**회원가입 허용 설정 (관리자)**
- Admin Area > Settings > General > Sign-up restrictions
- `Sign-up enabled` 체크 → 외부 사용자 자체 가입 가능
- 또는 비활성화 상태로 관리자가 직접 계정 생성

**관리자가 사용자 생성**
- Admin Area > Users > New user
- 이름, 이메일, 사용자명 입력 → 임시 비밀번호 발송

---

## 저장소(프로젝트) 생성

**그룹 생성** (팀/조직 단위)
- 좌측 메뉴 > Groups > New group
- 그룹명, 경로, 공개 범위 설정

**프로젝트 생성** (저장소)
- `+` 버튼 > New project > Create blank project
- 프로젝트명, 경로, 공개 범위 설정

**Clone URL 확인**
- 프로젝트 메인 > Clone 버튼
- HTTP: `http://gitlab.mgmt.local/<group>/<project>.git`
- SSH: `git@172.16.30.203:<group>/<project>.git`

---

## SSH 키 등록

```bash
# 키 생성 (없는 경우)
ssh-keygen -t ed25519 -C "your-email"

# 공개키 확인
cat ~/.ssh/id_ed25519.pub
```

GitLab > 우상단 아바타 > Edit profile > SSH Keys > 공개키 붙여넣기

**SSH 접속 설정** (`~/.ssh/config`)
```
Host gitlab.mgmt.local
  HostName 172.16.30.203
  Port 22
  User git
  IdentityFile ~/.ssh/id_ed25519
```

---

## 코드 push / pull

```bash
# 클론
git clone http://gitlab.mgmt.local/<group>/<project>.git

# 원격 추가 (기존 로컬 저장소)
git remote add origin http://gitlab.mgmt.local/<group>/<project>.git

# push
git push -u origin main

# pull
git pull origin main
```

---

## GitHub 미러링 (포트폴리오용)

GitLab 저장소를 GitHub에 자동으로 동기화하는 기능

**사전 조건**
- GitHub에 동일한 이름의 빈 저장소 생성
- GitHub Personal Access Token 발급 (Settings > Developer settings > PAT > `repo` 권한)

**미러링 설정**
1. GitLab 프로젝트 > Settings > Repository > Mirroring repositories
2. `Add new` 클릭
3. Git repository URL: `https://<github-username>@github.com/<github-username>/<repo>.git`
4. Mirror direction: **Push**
5. Authentication method: Password → GitHub PAT 입력
6. `Mirror repository` 저장

이후 GitLab에 push할 때마다 GitHub에 자동 동기화됨

**수동 동기화**
- Settings > Repository > Mirroring repositories > 새로고침 버튼

---

## CI/CD 파이프라인

`.gitlab-ci.yml` 파일을 저장소 루트에 작성하면 GitLab Runner(cicd-01)가 자동 실행

**기본 예시**
```yaml
stages:
  - build
  - deploy

build-job:
  stage: build
  tags:
    - shell
  script:
    - echo "빌드 실행"

deploy-job:
  stage: deploy
  tags:
    - terraform
  script:
    - terraform init
    - terraform apply -auto-approve
  only:
    - main
```

**Runner 태그**

| 태그 | 용도 |
|------|------|
| `shell` | 범용 |
| `terraform` | Terraform IaC |
| `ansible` | Ansible 플레이북 |

Runner 등록: `04.k8s/manifests/gitlab-operator/README.md` 참조

---

## ArgoCD 연동 (GitOps)

GitLab 저장소를 ArgoCD 소스로 등록하여 K8s 자동 배포 구성

**저장소 등록**
- ArgoCD UI (`http://argocd.mgmt.local`) > Settings > Repositories > Connect Repo
- Repository URL: `http://gitlab.mgmt.local/<group>/<project>.git`
- 인증: GitLab 계정 또는 Access Token

**Application 생성**
- Applications > New App
- Source: 위에서 등록한 GitLab 저장소, 경로, 브랜치
- Destination: 배포할 K8s 클러스터 및 네임스페이스
- Sync Policy: Automatic (자동 배포) 또는 Manual

---

## Harbor 연동 (컨테이너 이미지)

CI/CD 파이프라인에서 Harbor로 이미지 push

```yaml
# .gitlab-ci.yml
build-image:
  stage: build
  tags:
    - shell
  script:
    - docker login harbor.mgmt.local -u admin -p $HARBOR_PASSWORD
    - docker build -t harbor.mgmt.local/<project>/<image>:<tag> .
    - docker push harbor.mgmt.local/<project>/<image>:<tag>
```

GitLab 프로젝트 > Settings > CI/CD > Variables에 `HARBOR_PASSWORD` 등록
