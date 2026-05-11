# 기술스택 선정

## Git

- Github
- Gitlab (Selfhost CE)

## CI/CD

- Github Actions
- Gitlab Actions
- Jenkins

## Image Registry

- Harbor
- Github Registry
- DockerHub

## DB

- Percona
  - MySQL Cluster
- Galera
  - MariaDB Cluster
- MHA
  - Active-Standby

## Monitoring

- Prometheus
- Grafana

## Gitops

- ArgoCD

---

# Devops 조합

## SaaS

- Github + Github Actions + Dockerhub

## Onpremise

- Gitlab + Jenkins + Harbor
- Gitlab + Gitlab ACtions + Harbor

> SaaS -> 구축 X -> 설정만 추가하면 끝  
> Onpremise -> 구축 -> 설정

---

# DB 스택

- Master-Master
- MHA (Active-Standby)
  > Master-Master Percona를 소연님이 도와주면 금방할듯  
  > Active-Standby가 구축 자체는 더 쉬움

---

# K8S 클러스터 구축

- Master 클러스터링
  > Proxmox HA를 사용 -> 노드 죽으면 다른 노드로 이동 -> 이중화가 필요한가?  
  > Proxmox HA를 끄고 Master 클러스터링
  > Proxmox HA 여부에 고려해서 스펙 산정
- Worker 클러스터링
  > 마찬가지로 Proxmox HA를 사용할 것인지

---

# Proxmox HA

- Proxmox HA -> 각 노드에 옮길 수 있는 RAM, CPU, SSD를 남겨둬야함
