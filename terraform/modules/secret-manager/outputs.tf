output "secret_names" {
  description = "Map of secret logical names to their Secret Manager resource names"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.name }
}

output "db_password_secret_name" {
  value = google_secret_manager_secret.secrets["db-password"].name
}

output "jwt_secret_name" {
  value = google_secret_manager_secret.secrets["jwt-secret"].name
}
