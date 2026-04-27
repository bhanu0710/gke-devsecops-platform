variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "zone" {
  description = "GCP zone for the zonal cluster (us-central1-a gets free tier credit)"
  type        = string
  default     = "us-central1-a"
}

variable "network_name" {
  description = "VPC network name from vpc module"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name from vpc module"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary IP range name for pods"
  type        = string
}

variable "services_range_name" {
  description = "Secondary IP range name for services"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR for the control plane private endpoint"
  type        = string
  default     = "172.16.0.0/28"
}

variable "private_endpoint" {
  description = "Whether to disable the public control plane endpoint (true for prod)"
  type        = bool
  default     = false
}

variable "authorized_networks" {
  description = "List of CIDR blocks authorized to reach the control plane"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    { cidr_block = "0.0.0.0/0", display_name = "all" }
  ]
}

variable "machine_type" {
  description = "Node machine type — e2-medium gives 2 vCPU / 4GB RAM, sufficient for demo"
  type        = string
  default     = "e2-medium"
}

variable "min_node_count" {
  description = "Minimum nodes per zone (0 enables scale-to-zero for cost savings)"
  type        = number
  default     = 0
}

variable "max_node_count" {
  description = "Maximum nodes per zone"
  type        = number
  default     = 3
}

variable "node_service_account" {
  description = "Service account email for GKE nodes (created by IAM module)"
  type        = string
}

variable "environment" {
  description = "Environment name (staging / prod)"
  type        = string
}
