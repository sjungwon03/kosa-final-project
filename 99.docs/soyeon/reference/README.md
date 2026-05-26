# 🐳 Harbor 사설 저장소 가이드

본 폴더는 Proxmox 쿠버네티스 클러스터 환경에 Harbor 사설 레지스트리를 배포하기 위한 인프라 코드입니다. 

원래 `values.yaml`과 `harbor-secret.yaml` 파일만 있어도 배포할 수 있지만, ArgoCD 자동 배포(GitOps) 연동과 문법 검사를 위해 `Chart.yaml`을 추가하여 구조를 잡았습니다.

---

## 📌 주요 인프라 정보
- **웹 UI 주소:** `https://harbor.192.168.34.2.nip.io:32445`
- **초기 관리자 정보:** ID: `admin` / PW: `Kosa1004`

---

## 📁 파일 구조 및 역할

### 1. `values.yaml`
- **위치**: `root@harbor:~/k8s-yamls/harbor#`
- **역할**: Harbor의 가동 방식, 주소 체계, 저장소 공간, 보안 기능 등을 활성화할지 그 여부를 결정하는 핵심 파일입니다.
- **주요 내용**: Ingress TLS 설정, `trivy` 취약점 진단 및 `chartmuseum` 활성화가 포함되어 있습니다.

### 2. `harbor-secret.yaml`
- **위치**: `root@harbor:~/k8s-yamls/harbor#`
- **역할**: ArgoCD를 통해 클러스터에 배포되기 전, harbor 내부 시스템들이 사용할 암호 정보(Admin 웹 접속, DB 접속, 모듈용 내부 보안 키)를 정의하는 파일입니다.

### 3. `Chart.yaml`
- **위치**: `root@harbor:~/k8s-yamls/harbor#`
- **역할**: 쿠버네티스가 이 폴더를 공식 헬름 차트로 인식하게 만들어 문법 검사가 가능해지고, ArgoCD 담당자의 연동 작업을 도와주는 파일입니다. (공식 Harbor 헬름 레포지토리 v1.14.0 주소 연동)

---

## 🚀 리포지토리 등록 + 의존성 동기화 + 문법 검사

배포 전 로컬 환경에서 테스트하거나 뼈대 파일을 업데이트할 때 아래 명령어를 순서대로 실행합니다.

1. **헬름 리포지토리 등록**
   ```bash
   helm repo add harbor github.com
   ```
2. **의존성 동기화**
   ```bash
   helm dependency update .
   ```
3. **매니페스트 문법 검사 (`0 chart(s) failed` 확인 필수)**
   ```bash
   helm lint .
   ```

---

## 🛠 팀원별 연동 가이드

### 1. **[GitLab CI 담당자]**
- CI 파이프라인 스크립트 실행 전 아래 명령어로 로그인을 선행해야 합니다.
  ```bash
  docker login harbor.192.168.34.2.nip.io:32445
  ```
- 빌드 파이프라인 연동 시, 보안을 위해 개인 계정이 아닌 Harbor 내부에서 전용 **Robot Account**를 발급하여 토큰 형태로 사용하시는 것을 권장합니다.

### 2. **[ArgoCD / 인프라 담당자]**
- **스토리지 설정**: 데이터 보존을 위해 `persistence.enabled: true`가 켜져 있습니다. 클러스터 환경의 StorageClass 명칭에 맞게 `values.yaml` 하단의 `storageClass` 이름을 매칭한 뒤 배포(Sync)해 주세요. (현재 임시로 `local-path` 지정됨)
- **런타임 보안 설정**: 사설 인증서 환경이므로 K8s 모든 노드의 컨테이너 런타임 설정에 아래와 같이 비인증 레지스트리 추가가 필요합니다.
  ```json
  insecure-registries: ["harbor.192.168.34.2.nip.io:32445"]
  ```
