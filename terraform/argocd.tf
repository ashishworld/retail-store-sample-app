# =============================================================================
# ARGOCD INSTALLATION AND CONFIGURATION
# =============================================================================

# Wait for the cluster and add-ons to be ready
resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on = [
    module.retail_app_eks,
    module.eks_addons
  ]
}

# =============================================================================
# ARGOCD HELM INSTALLATION
# =============================================================================

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # ArgoCD configuration values
  values = [
    yamlencode({
      # Server configuration
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = false  # We'll use port-forward for access
        }
        # Enable insecure mode for easier local access
        extraArgs = [
          "--insecure"
        ]
      }
      
      # Controller configuration
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      
      # Repo server configuration
      repoServer = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }
      
      # Redis configuration
      redis = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [time_sleep.wait_for_cluster]
}

# =============================================================================
# WAIT FOR ARGOCD TO BE READY
# =============================================================================

resource "time_sleep" "wait_for_argocd" {
  create_duration = "60s"
  depends_on      = [helm_release.argocd]
}

# =============================================================================
# DEPLOY ARGOCD APPLICATIONS
# =============================================================================

# Note: ArgoCD applications need to be deployed manually after Terraform completes
# Run these commands manually:
# kubectl apply -n argocd -f ../argocd/projects/
# kubectl apply -n argocd -f ../argocd/applications/

resource "null_resource" "argocd_apps" {
  depends_on = [time_sleep.wait_for_argocd]
  
  # Trigger re-deployment if ArgoCD configuration changes
  triggers = {
    argocd_version = var.argocd_chart_version
    timestamp      = timestamp()
  }
}
