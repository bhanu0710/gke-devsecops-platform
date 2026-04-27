variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "authorized_networks" {
  description = "Only these CIDRs can reach the prod control plane — set to your VPN/bastion IP"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    { cidr_block = "10.0.0.0/8", display_name = "internal-only" }
  ]
}
