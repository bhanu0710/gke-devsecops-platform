# environments/staging/main.tf
# Staging environment wires all modules together.
# Staging differs from prod: public control plane endpoint enabled,
# smaller resource quotas, and min_node_count=0 for cost savings.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # Bucket name is set via -backend-config or TF_CLI_ARGS_init
    # to avoid hardcoding the project-specific bucket name here.
    # Usage: terraform init -backend-config="bucket=${PROJECT_ID}-tf-state"
    prefix = "staging"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ── IAM phase 1: service accounts only — no WI bindings (GKE doesn't exist yet) ──
module "iam" {
  source             = "../../modules/iam"
  project_id         = var.project_id
  create_wi_bindings = false
}

# ── IAM phase 2: WI bindings — inline resources so depends_on = [module.gke] works ──
# These can't be in the iam module because module.gke depends on module.iam (circular).
# The svc.id.goog pool is created by GKE; bindings must come after.
resource "google_service_account_iam_member" "argocd_wi" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/argocd-sa@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[argocd/argocd-server]"
  depends_on         = [module.iam, module.gke]
}

resource "google_service_account_iam_member" "jenkins_wi" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/jenkins-sa@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[jenkins/jenkins]"
  depends_on         = [module.iam, module.gke]
}

resource "google_service_account_iam_member" "app_wi_staging" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/app-sa@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[staging/app-workload]"
  depends_on         = [module.iam, module.gke]
}

resource "google_service_account_iam_member" "app_wi_prod" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/app-sa@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[prod/app-workload]"
  depends_on         = [module.iam, module.gke]
}

# ── VPC ──────────────────────────────────────────────────────────────────────
module "vpc" {
  source      = "../../modules/vpc"
  project_id  = var.project_id
  name_prefix = "devsecops-staging"
  region      = var.region

  subnet_cidr            = "10.0.0.0/16"
  pods_cidr              = "10.1.0.0/16"
  services_cidr          = "10.2.0.0/16"
  master_ipv4_cidr_block = "172.16.0.0/28"
}

# ── GKE Cluster ───────────────────────────────────────────────────────────────
module "gke" {
  source     = "../../modules/gke"
  project_id = var.project_id

  cluster_name  = "devsecops-staging"
  zone          = var.zone
  environment   = "staging"

  network_name        = module.vpc.network_name
  subnet_name         = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name

  master_ipv4_cidr_block = "172.16.0.0/28"
  private_endpoint       = false # Staging: allow public kubectl access for simplicity

  machine_type         = "e2-medium"
  min_node_count       = 0 # Scale-to-zero when not in use
  max_node_count       = 3
  node_service_account = module.iam.node_sa_email

  depends_on = [module.vpc, module.iam]
}

# ── Artifact Registry ─────────────────────────────────────────────────────────
module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  location   = "us-central1"
  environment = "staging"

  argocd_sa_email  = module.iam.argocd_sa_email
  jenkins_sa_email = module.iam.jenkins_sa_email

  depends_on = [module.iam]
}

# ── Secret Manager ────────────────────────────────────────────────────────────
module "secrets" {
  source       = "../../modules/secret-manager"
  project_id   = var.project_id
  environment  = "staging"
  app_sa_email = module.iam.app_sa_email

  depends_on = [module.iam]
}
