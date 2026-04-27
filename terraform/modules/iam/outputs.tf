output "argocd_sa_email" {
  value = google_service_account.accounts["argocd-sa"].email
}

output "jenkins_sa_email" {
  value = google_service_account.accounts["jenkins-sa"].email
}

output "app_sa_email" {
  value = google_service_account.accounts["app-sa"].email
}

output "node_sa_email" {
  description = "GKE node service account — passed to GKE module node_service_account"
  value       = google_service_account.accounts["node-sa"].email
}
