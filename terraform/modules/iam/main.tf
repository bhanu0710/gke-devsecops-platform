# modules/iam/main.tf
# Creates GCP service accounts and binds them to Kubernetes service accounts
# via Workload Identity. This eliminates the need to mount static JSON key files
# into pods — each pod authenticates to GCP using its K8s identity token.

locals {
  # Map of {gcp_sa_name → {namespace, k8s_sa_name, roles}}
  service_accounts = {
    "argocd-sa" = {
      display_name = "ArgoCD GitOps SA"
      namespace    = "argocd"
      k8s_sa_name  = "argocd-server"
      roles        = ["roles/artifactregistry.reader"]
    }
    "jenkins-sa" = {
      display_name = "Jenkins CI SA"
      namespace    = "jenkins"
      k8s_sa_name  = "jenkins"
      roles = [
        "roles/artifactregistry.writer",
        "roles/secretmanager.secretAccessor",
        "roles/storage.objectCreator", # For build artifacts
      ]
    }
    "app-sa" = {
      display_name = "Application workloads SA"
      namespace    = "staging" # Also bound to prod namespace via separate binding
      k8s_sa_name  = "app-workload"
      roles        = ["roles/secretmanager.secretAccessor"]
    }
    "node-sa" = {
      display_name = "GKE Node SA"
      namespace    = ""
      k8s_sa_name  = ""
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.viewer",
        "roles/artifactregistry.reader", # Nodes pull images for system components
      ]
    }
  }
}

resource "google_service_account" "accounts" {
  for_each = local.service_accounts

  project      = var.project_id
  account_id   = each.key
  display_name = each.value.display_name
}

# Grant each SA its required project-level roles
resource "google_project_iam_member" "sa_roles" {
  for_each = {
    for entry in flatten([
      for sa_name, sa_config in local.service_accounts : [
        for role in sa_config.roles : {
          key     = "${sa_name}-${role}"
          sa_name = sa_name
          role    = role
        }
      ]
    ]) : entry.key => entry
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.accounts[each.value.sa_name].email}"
}

# Workload Identity binding: allows the K8s SA to impersonate the GCP SA.
# This is the magic that lets pods call GCP APIs without JSON keys.
# Binding is: k8s SA in namespace X can act as GCP SA Y
resource "google_service_account_iam_member" "workload_identity_bindings" {
  for_each = var.create_wi_bindings ? {
    for sa_name, sa_config in local.service_accounts :
    sa_name => sa_config
    if sa_config.namespace != "" # node-sa has no K8s SA binding
  } : {}

  service_account_id = google_service_account.accounts[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.k8s_sa_name}]"
}

# Extra binding for app-sa in prod namespace (same GCP SA, different K8s namespace)
resource "google_service_account_iam_member" "app_sa_prod_binding" {
  count = var.create_wi_bindings ? 1 : 0

  service_account_id = google_service_account.accounts["app-sa"].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[prod/app-workload]"
}
