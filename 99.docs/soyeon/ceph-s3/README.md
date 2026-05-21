## Prometheus + Grafana + Thanos 설치 시작
## Grafana 접속 (http://172.16.30.45:30300/)  
① Connections → Data sources → Add new data source 선택
<img width="1918" height="672" alt="1" src="https://github.com/user-attachments/assets/4e1b714c-c254-4974-807e-b7360f546df7" />


② DNS 조회 실패 → 내부 URL 변경  
Grafana에서 Prometheus 데이터소스 연결 시 기본 URL이 너무 길어 DNS 조회 실패 발생  
prometheus-operated 는 Prometheus Operator가 자동 생성하는 고정 서비스명으로,  
Grafana와 동일한 monitoring 네임스페이스 내에 있어 짧은 이름으로 통신 가능  
기존 URL → http://monitoring-kube-prometheus-prometheus.monitoring:9090  
변경 URL → http://prometheus-operated.monitoring:9090  
URL 변경 후 Save & test 클릭, "Successfully queried the Prometheus API" 확인

<img width="1918" height="717" alt="2-2" src="https://github.com/user-attachments/assets/5dd105c1-506c-4cae-9e10-0e272cdbf31b" />


③ Prometheus-1 생성  
method → 기본값 설정  
Series limit → 기본값 설정  
Connection → 변경한 url로 새로 설정  
<img width="1395" height="787" alt="3-1" src="https://github.com/user-attachments/assets/94849e0d-3584-4fd7-8bfb-1709537ba585" />
<img width="1918" height="833" alt="3-2" src="https://github.com/user-attachments/assets/00e9a7df-1edb-4f5e-9a3d-153179401e15" />


④ Dashboards → News → import → 1860 선택 → import 클릭  
Grafana가 자동으로 `grafana.com/dashboards/1860` 으로 접속  
Node Exporter Full의 json 대시보드를 다운로드해 grafana에 설치  
<img width="1918" height="845" alt="4-1" src="https://github.com/user-attachments/assets/0e3a710d-122a-406c-95a6-91d2ea959a54" />
<img width="1918" height="866" alt="4-2" src="https://github.com/user-attachments/assets/00a2e0d3-7be7-4d8f-9558-0eb77a447fa6" />
<img width="1440" height="803" alt="4-3" src="https://github.com/user-attachments/assets/29930a46-b746-472f-814b-d1dd9e0bc3ab" />
<img width="1506" height="775" alt="4-4" src="https://github.com/user-attachments/assets/39b633fd-7816-4a7c-b397-e70c693da342" />


⑤ Dashboards 화면  
Node Exporter가 k8s-master-01 노드의 metrics를 수집  
Prometheus가 저장  
Grafana가 Basic CPU / Mem / Net / Disk 섹션으로 나눠 대시보드로 시각화  
<img width="1918" height="857" alt="5" src="https://github.com/user-attachments/assets/71e5ce9c-8804-430c-a8e6-3fd418a74f98" />
