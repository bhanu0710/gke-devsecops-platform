variable "project_id" {
  type = string
}

variable "location" {
  description = "Must match GKE region to avoid egress charges on image pulls"
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  type    = string
  default = "devsecops-platform"
}

variable "environment" {
  type = string
}

variable "argocd_sa_email" {
  description = "ArgoCD GCP service account that needs to pull images"
  type        = string
}

variable "jenkins_sa_email" {
  description = "Jenkins GCP service account that needs to push built images"
  type        = string
}
