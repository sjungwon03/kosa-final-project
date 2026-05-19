apiVersion: karpenter.sh/v1beta1
kind: Provisioner
metadata:
  name: cloudburst
spec:
  requirements:
    - key: karpenter.k8s.aws/instance-family
      operator: In
      values: ["t3", "t3a", "t2"]
    - key: karpenter.k8s.aws/instance-size
      operator: In
      values: ["micro", "small", "medium"]
    - key: topology.kubernetes.io/zone
      operator: In
      values: ["ap-northeast-2a", "ap-northeast-2b"]
    - key: kubernetes.io/arch
      operator: In
      values: ["amd64"]
  
  providerRef:
    name: cloudburst-provider
  
  limits:
    resources:
      cpu: 100
      memory: 100Gi
  
  consolidation:
    enabled: true
  
  ttlSecondsAfterEmpty: 30
  ttlSecondsUntilExpired: 2592000

---
apiVersion: karpenter.k8s.aws/v1beta1
kind: AWSNodeTemplate
metadata:
  name: cloudburst-provider
spec:
  subnetSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
  
  securityGroupSelector:
    karpenter.sh/discovery: ${CLUSTER_NAME}
  
  amiSelector:
    aws-eks/managed: "true"
  
  userData: |
    #!/bin/bash
    echo "Node created by Karpenter for cloudburst"
  
  tags:
    karpenter.sh/discovery: ${CLUSTER_NAME}
    Purpose: cloudburst

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: kosa
spec:
  replicas: 0
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: ${IMAGE_REGISTRY}/api-gateway:latest
        ports:
        - containerPort: 8000
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: api-gateway

---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: kosa
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  selector:
    app: api-gateway
  ports:
  - port: 80
    targetPort: 8000
    protocol: TCP