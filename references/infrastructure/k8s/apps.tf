resource "kubernetes_namespace" "kosa" {
  metadata {
    name = var.k8s_namespace
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = var.k8s_namespace
  
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  
  create_namespace = true
  
  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "redis" {
  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  namespace  = var.k8s_namespace
  
  set {
    name  = "auth.enabled"
    value = "false"
  }
  
  set {
    name  = "master.persistence.enabled"
    value = "true"
  }
  
  set {
    name  = "master.persistence.size"
    value = "1Gi"
  }
}