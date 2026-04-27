# environments/prod/main.tf
# Production environment — stricter settings than staging:
# - Private control plane endpoint (no public kubectl access)
# - Higher min_node_count (1 instead of 0, avoids cold-start latency)
# - Separate state prefix so staging and prod never share state

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
    prefix = "prod"
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

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
}

module "vpc" {
  source      = "../../modules/vpc"
  project_id  = var.project_id
  name_prefix = "devsecops-prod"
  region      = var.region

  # Separate CIDRs from staging to prevent any accidental routing overlap
  subnet_cidr            = "10.10.0.0/16"
  pods_cidr              = "10.11.0.0/16"
  services_cidr          = "10.12.0.0/16"
  master_ipv4_cidr_block = "172.17.0.0/28"
}

module "gke" {
  source     = "../../modules/gke"
  project_id = var.project_id

  cluster_name = "devsecops-prod"
  zone         = var.zone
  environment  = "prod"

  network_name        = module.vpc.network_name
  subnet_name         = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name

  master_ipv4_cidr_block = "172.17.0.0/28"
  private_endpoint       = true # Prod: disable public control plane endpoint

  machine_type         = "e2-standard-2" # 2 vCPU / 8GB — more headroom for prod workloads
  min_node_count       = 1               # Keep at least 1 node warm in prod
  max_node_count       = 5
  node_service_account = module.iam.node_sa_email

  # Only the VPN/bastion CIDR should reach prod control plane
  authorized_networks = var.authorized_networks

  depends_on = [module.vpc, module.iam]
}

module "artifact_registry" {
  source      = "../../modules/artifact-registry"
  project_id  = var.project_id
  location    = "us-central1"
  environment = "prod"

  argocd_sa_email  = module.iam.argocd_sa_email
  jenkins_sa_email = module.iam.jenkins_sa_email

  depends_on = [module.iam]
}

module "secrets" {
  source       = "../../modules/secret-manager"
  project_id   = var.project_id
  environment  = "prod"
  app_sa_email = module.iam.app_sa_email

  depends_on = [module.iam]
}
