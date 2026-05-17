# GitLab Operator

공식 문서: https://docs.gitlab.com/operator/installation/

## 설치 (manifest 방식)

```bash
export GL_OPERATOR_VERSION=2.9.0
export PLATFORM=kubernetes
kubectl create namespace gitlab-system --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "https://gitlab.com/api/v4/projects/18899486/packages/generic/gitlab-operator/${GL_OPERATOR_VERSION}/gitlab-operator-${PLATFORM}-${GL_OPERATOR_VERSION}.yaml"
```

## GitLab CR 배포

```bash
kubectl -n gitlab-system apply -f gitlab.yaml
kubectl -n gitlab-system get gitlab
kubectl -n gitlab-system logs deployment/gitlab-controller-manager -c manager -f
```

## 삭제

```bash
kubectl -n gitlab-system delete -f gitlab.yaml
kubectl delete -f "https://gitlab.com/api/v4/projects/18899486/packages/generic/gitlab-operator/${GL_OPERATOR_VERSION}/gitlab-operator-${PLATFORM}-${GL_OPERATOR_VERSION}.yaml"
```
