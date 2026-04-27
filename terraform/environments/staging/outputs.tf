output "cluster_name" {
  value = module.gke.cluster_name
}

output "registry_url" {
  value = module.artifact_registry.repository_url
}

output "gke_connect_command" {
  description = "Run this to configure kubectl for this cluster"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${var.zone} --project ${var.project_id}"
}
