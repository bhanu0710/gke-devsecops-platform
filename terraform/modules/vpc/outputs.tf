output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "Self-link of the VPC network (used by GKE module)"
  value       = google_compute_network.main.self_link
}

output "subnet_name" {
  description = "Name of the primary subnet"
  value       = google_compute_subnetwork.main.name
}

output "subnet_self_link" {
  description = "Self-link of the primary subnet (used by GKE module)"
  value       = google_compute_subnetwork.main.self_link
}

output "pods_range_name" {
  description = "Secondary IP range name for pods (passed to GKE cluster config)"
  value       = "pods"
}

output "services_range_name" {
  description = "Secondary IP range name for services (passed to GKE cluster config)"
  value       = "services"
}
