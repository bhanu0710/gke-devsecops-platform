# backend.tf — documentation file only
# Each environment has its own backend configured in its own main.tf.
# This file documents the bucket naming convention.
#
# Bucket: ${GCP_PROJECT_ID}-tf-state
# Staging state: gs://${GCP_PROJECT_ID}-tf-state/staging/default.tfstate
# Prod state:    gs://${GCP_PROJECT_ID}-tf-state/prod/default.tfstate
#
# Initialize with:
#   terraform init -backend-config="bucket=${GCP_PROJECT_ID}-tf-state"
