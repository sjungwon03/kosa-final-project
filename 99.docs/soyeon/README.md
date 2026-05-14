# 🐳 Harbor 사설 저장소 가이드

본 폴더는 Proxmox 쿠버네티스 클러스터 환경에 Harbor 사설 레지스트리를 배포하기 위한 인프라 코드입니다.

## 📌 주요 인프라 정보
- **웹 UI 주소:** `nip.io`
- **초기 관리자 정보:** ID: `admin` / PW: `Harbor12345`

## 🛠️ 팀원별 연동 가이드
1. **[GitLab CI 담당자]** 
   - CI 파이프라인 스크립트 실행 전 아래 명령어로 로그인을 선행해야 합니다.
   - `docker login harbor.192.168.34.2.nip.io:32445`
2. **[ArgoCD / 인프라 담당자]**
   - 데이터 보존을 위해 `persistence.enabled: true`가 켜져 있습니다. 클러스터 환경의 StorageClass 명칭에 맞게 `values.yaml` 하단의 `storageClass` 이름을 매칭한 뒤 배포(Sync)해 주세요.
   - 사설 인증서 환경이므로 K8s 모든 노드의 컨테이너 런타임 설정에 `insecure-registries: ["harbor.192.168.34.2.nip.io:32445"]` 추가가 필요합니다.
