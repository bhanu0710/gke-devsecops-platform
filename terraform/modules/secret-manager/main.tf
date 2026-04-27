# modules/secret-manager/main.tf
# Creates secret placeholders in Secret Manager. Actual secret VALUES are set
# manually (gcloud secrets versions add) or via Vault after bootstrap.
# Terraform manages the secret RESOURCE (metadata, labels, IAM) but never the value,
# so sensitive data never appears in terraform.tfstate.

locals {
  secrets = {
    "db-password"  = "PostgreSQL password for application services"
    "jwt-secret"   = "HMAC-SHA256 key for JWT signing in user-service"
    "app-api-key"  = "Internal API key for inter-service authentication"
    "vault-token"  = "Initial Vault root token (rotated after first login)"
    "cosign-key"   = "Cosign private key reference for image signing"
  }
}

resource "google_secret_manager_secret" "secrets" {
  for_each = local.secrets

  project   = var.project_id
  secret_id = each.key

  labels = {
    managed-by  = "terraform"
    environment = var.environment
  }

  replication {
    # Automatic replication is free and spreads secrets across Google's infrastructure.
    # User-managed replication would let us pin to specific regions but costs more.
    auto {}
  }
}

# Allow the application SA to read secrets — least privilege.
# Only the app-sa can read; Terraform SA cannot read values (separation of concerns).
resource "google_secret_manager_secret_iam_member" "app_accessor" {
  for_each = google_secret_manager_secret.secrets

  project   = var.project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.app_sa_email}"
}
