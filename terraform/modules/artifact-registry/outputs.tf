output "repository_url" {
  description = "Full repository URL used in docker push/pull and Helm values"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}

output "repository_name" {
  value = google_artifact_registry_repository.main.name
}
