resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.20"
  namespace        = "argo"
  create_namespace = true

  values = [templatefile("${path.module}/values/argocd.yaml", {
    cert_arn      = var.acm_certificate_arn
    argocd_domain = var.argocd_domain
    alb_group     = var.name
  })]
}

resource "kubernetes_secret_v1" "argocd_cluster" {
  metadata {
    name      = var.name
    namespace = "argo"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "environment"                    = var.environment
    }
    annotations = {
      "managed-by" = "argocd.argoproj.io"
    }
  }

  data = {
    name   = var.name
    server = "https://kubernetes.default.svc"
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
      }
    })
  }

  depends_on = [helm_release.argocd]
}
