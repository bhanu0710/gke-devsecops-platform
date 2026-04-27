variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "app_sa_email" {
  description = "App service account that should be able to read secrets"
  type        = string
}
