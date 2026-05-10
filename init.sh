#!/bin/bash

# KOSA 프로젝트 초기화 스크립트

set -e

echo "KOSA 프로젝트 초기화 시작..."

# 백엔드 의존성 설치
echo "백엔드 의존성 설치 중..."
cd backend
poetry install
cd ..

# 프론트엔드 의존성 설치
echo "프론트엔드 의존성 설치 중..."
cd frontend
npm install
cd ..

# 환경 변수 파일 생성
echo "환경 변수 파일 생성 중..."
if [ ! -f backend/.env ]; then
    cp backend/.env.example backend/.env
    echo "backend/.env 파일이 생성되었습니다. 설정을 확인해주세요."
fi

# DB 초기화
echo "DB 초기화 중..."
./init-db.sh

echo "KOSA 프로젝트 초기화 완료!"
echo ""
echo "다음 명령어로 로컬 환경을 실행할 수 있습니다:"
echo "  docker-compose up -d"
echo ""
echo "개발자 가이드: README.md를 참조하세요."