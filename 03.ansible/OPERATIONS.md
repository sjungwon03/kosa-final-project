# 인프라 운영 가이드

> 초기 구축 이후 서비스 운영 단계에서 발생하는 반복 작업 및 장애 대응 가이드임
> 모든 작업은 **Control Node**에서 수행하며 앤서블을 통한 선언적 관리를 원칙으로 함

**목차**
- [DNS 관리](#1-dns-및-도메인-관리-coredns--etcd)
- [Vault 관리](#3-보안-서버-관리-vault)
- [K8s 확장](#2-k8s-클러스터-확장-및-관리)
- [점검](#4-모니터링-및-로깅-상태-점검)

---

## 1. DNS 및 도메인 관리 (CoreDNS + etcd)

새로운 서비스를 추가하거나 IP 변경 시 앤서블 변수 파일 수정을 통해 반영함

### 도메인 추가/수정 절차
1. **변수 파일 수정**: `inventories/<env>/group_vars/dns_servers.yml`에 레코드 추가
   ```yaml
   dns_records:
     - { name: "new-service", ip: "172.16.30.XXX", domain: "svc.local" }
   ```
2. **설정 주입**: 앤서블 플레이북 실행
   ```bash
   ansible-playbook playbooks/dns.yml
   ```
3. **결과 확인**: `dig` 명령어로 레코드 조회 확인
   ```bash
   dig @172.16.30.10 new-service.svc.local
   ```

---

## 2. K8s 클러스터 확장 및 관리

### 워커 노드 확장 (Scale-out)
1. **Terraform 프로비저닝**: `tfvars` 파일에 노드 정보 추가 후 `apply` 실행
2. **Cluster Join**: 앤서블 인벤토리에 IP 추가 후 플레이북 실행
   ```bash
   # 신규 노드만 타겟팅하여 실행
   ansible-playbook playbooks/k8s.yml --limit <NEW_NODE_IP>
   ```

### 노드 제거 및 점검
1. **Drain 및 Delete**: 마스터 노드에서 해당 노드 자원 비우기 및 삭제
   ```bash
   kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data
   kubectl delete node <NODE_NAME>
   ```
2. **Terraform 정리**: `tfvars`에서 해당 항목 삭제 후 `apply` 실행

---

## 3. 보안 서버 관리 (Vault)

Vault 봉인(Sealed) 상태 해제 및 인증 관리

### Unseal 절차
VM 재부팅 등으로 Vault가 Sealed 상태일 때 서비스 복구를 위해 수행함
1. **상태 확인**: `vault status`
2. **봉인 해제**: 초기 구축 시 발급된 3개의 Unseal Key를 순차 주입
   ```bash
   vault operator unseal <KEY_1>
   vault operator unseal <KEY_2>
   vault operator unseal <KEY_3>
   ```

---

## 4. 모니터링 및 로깅 상태 점검

### 에이전트 일괄 점검
전체 VM의 데이터 수집 에이전트 동작 여부 확인
```bash
# 로그(Promtail) 및 보안(Wazuh) 에이전트 상태 확인
ansible all -m systemd -a "name=promtail state=started"
ansible all -m systemd -a "name=wazuh-agent state=started"
```

> [!IMPORTANT]
> 직접 `etcdctl` 등으로 데이터를 수정하는 것은 지양함
> 인프라 재구축 시 데이터 소실 방지를 위해 반드시 **앤서블 코드를 먼저 수정**하고 주입하는 프로세스를 준수할 것
