#!/bin/bash
# FlaskApp 로컬 컨테이너 실행 스크립트 (테스트용)
# 실제 값은 .env 파일 참고

docker run -d \
  -p 8080:80 \
  --name flaskapp-test \
  -e PHOTOS_BUCKET=${PHOTOS_BUCKET:-dummy} \
  -e DATABASE_HOST=${DATABASE_HOST:-dummy} \
  -e DATABASE_USER=${DATABASE_USER:-dummy} \
  -e DATABASE_DB_NAME=${DATABASE_DB_NAME:-dummy} \
  -e DATABASE_PASSWORD=${DATABASE_PASSWORD:-dummy} \
  -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-ap-northeast-2} \
  flaskapp:latest

echo "컨테이너 실행 완료. http://localhost:8080/info 에서 확인"
