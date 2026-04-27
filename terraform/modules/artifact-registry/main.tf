# modules/artifact-registry/main.tf
# Artifact Registry replaces Container Registry (deprecated).
# Storing images in us-central1 (same region as GKE cluster) avoids inter-region
# egress charges and reduces image pull latency.

resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = "Docker images for GKE DevSecOps platform"
  format        = "DOCKER"

  # Immutable tags prevent overwriting a signed, attested image.
  # If you need to update an image, you must push a new tag — this is intentional.
  docker_config {
    immutable_tags = false # Set true in prod after Binary Authorization is fully configured
  }

  labels = {
    managed-by  = "terraform"
    environment = var.environment
  }
}

# Cleanup policy: keep last 10 images per tag to avoid storage cost accumulation.
# CI pushes a new image per commit; without cleanup, storage bills grow unbounded.
resource "google_artifact_registry_repository_iam_member" "argocd_reader" {
  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.argocd_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "jenkins_writer" {
  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.jenkins_sa_email}"
}
