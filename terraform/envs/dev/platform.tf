# Cluster platform add-ons installed with Helm: ingress, autoscaling metrics, monitoring, GitOps.

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.11.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  values = [yamlencode({
    controller = {
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
        }
      }
      metrics = {
        enabled        = true
        serviceMonitor = { enabled = true, additionalLabels = { release = "kube-prometheus-stack" } }
      }
    }
  })]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"
  namespace  = "kube-system"

  depends_on = [module.eks]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "66.3.1"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900

  values = [file("${path.module}/../../../monitoring/k8s/kube-prometheus-stack-values.yaml")]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  depends_on = [kubernetes_storage_class_v1.gp3]
}

resource "helm_release" "argocd" {
  count            = var.install_argocd ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.10"
  namespace        = "argocd"
  create_namespace = true

  depends_on = [module.eks]
}
