# binary-auth.tf — Binary Authorization policy requiring Cosign attestation.
# Any image that hasn't been signed by the CI pipeline's Cosign key is BLOCKED
# from being deployed. This closes the gap between "image built" and "image deployed" —
# you can't bypass the CI security checks by manually kubectl-applying an unsigned image.

resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  # Explicitly allow known-good Google system images to avoid breaking cluster operations
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }
  admission_whitelist_patterns {
    name_pattern = "gcr.io/gke-release/*"
  }
  admission_whitelist_patterns {
    name_pattern = "gcr.io/distroless/*"
  }
  admission_whitelist_patterns {
    name_pattern = "docker.io/istio/*"
  }

  # All other images must have a valid attestation from our Cosign key
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      google_binary_authorization_attestor.cosign.name
    ]
  }
}

# KMS key for Cosign image signing
resource "google_kms_key_ring" "cosign" {
  project  = var.project_id
  name     = "cosign-keyring"
  location = "global"
}

resource "google_kms_crypto_key" "cosign" {
  name     = "cosign-key"
  key_ring = google_kms_key_ring.cosign.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"
  }

  # Prevent accidental deletion of the signing key — would invalidate all attestations
  lifecycle {
    prevent_destroy = true
  }
}

# Attestor links the Binary Authorization policy to the Cosign KMS key
resource "google_binary_authorization_attestor" "cosign" {
  project = var.project_id
  name    = "cosign-attestor"

  attestation_authority_note {
    note_reference = google_container_analysis_note.cosign.name

    public_keys {
      id = data.google_kms_crypto_key_version.cosign_version.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.cosign_version.public_key[0].pem
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }
}

resource "google_container_analysis_note" "cosign" {
  project = var.project_id
  name    = "cosign-attestation-note"

  attestation_authority {
    hint {
      human_readable_name = "Cosign CI attestor — images signed by the CI pipeline"
    }
  }
}

data "google_kms_crypto_key_version" "cosign_version" {
  crypto_key = google_kms_crypto_key.cosign.id
}

variable "project_id" {
  type = string
}
