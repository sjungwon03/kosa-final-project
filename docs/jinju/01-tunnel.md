# 외부 접근

## Cloudflare Tunnel

// 임시 방법임

1. 프록스목스에 클라우드플레어 설치
2. 노트북에 클라우드플레어 설치
3. 노트북에서 키 생성 후 프록스목스에 저장
4. 프록스목스에서 클라우드플레어 SSH 터널을 실행하고 연결 경로 확인
5. 노트북에서 접근되는지 확인 (랜선 제거 후 테스트해야 함)

프록스목스에서 작업

```
# deb 패키지 다운로드 및 설치
curl -L --output cloudflared.deb \https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb


# 설치 확인
cloudflared -v


# 백그라운드 실행 + 로그 저장 (연결할 프록스목스 아이피로 수정)
nohup cloudflared tunnel --url ssh://172.16.43.4:22 > tunnel.log 2>&1 &

# 터널 URL 확인 (로그에 나오는 경로 연결)
cat tunnel.log


# 실행중인 클라우드플레어 PID 확인
ps -ef | grep cloudflared

# 재시작이 필요한 경우 kill
pkill -9 cloudflared
```

노트북에서 작업

```bash
# 키 생성
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_cloudflare

# 공개키를 확인해 프록스목스에 저장
cat ~/.ssh/id_rsa_cloudflare.pub
```

프록스목스에서 작업

```bash
# ssh 폴더가 없으면 생성
mkdir -p ~/.ssh

# 키 등록 // 예시이므로 키 값 수정해야 함
echo "디스코드 확인" >> ~/.ssh/authorized_keys`

chmod 600 ~/.ssh/authorized_keys
```

노트북에서 작업

````bash
# deb 패키지 다운로드 및 설치
curl -L --output cloudflared.deb \https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

sudo dpkg -i cloudflared.deb

# 설치 확인
cloudflared -v


# 프록스목스 접근 (로그에 나온 경로를 넣어야 함)
ssh -i ~/.ssh/id_rsa_cloudflare \
    -o "ProxyCommand=cloudflared access ssh --hostname %h" \
    root@bet-mileage-guardian-ment.trycloudflare.com



프록스목스 접근
ssh -i ~/.ssh/id_rsa_cloudflare \
    -o "ProxyCommand=cloudflared access ssh --hostname %h" \
    root@bigger-popular-sec-amd.trycloudflare.com

프록스목스 UI
ssh -i ~/.ssh/id_rsa_cloudflare \
    -o "ProxyCommand=cloudflared access ssh --hostname %h" \
    -L 8006:localhost:8006 \
    root@bigger-popular-sec-amd.trycloudflare.com




집에 등록
다른 노트북으로 접근하는 경우 개인키를 가지고 있어야 함

```bash
vi ~/.ssh/id_rsa_cloudflare
디스코드 확인
````
