#!/usr/bin/env bash
# setup.sh — One-command GCP project bootstrap
# Run this once before any Terraform. It provisions the remote state bucket,
# Terraform service account, required APIs, and billing alerts.
# Why a single script: reproducibility across machines without manual console clicks.
set -euo pipefail

# ── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Prerequisite check ───────────────────────────────────────────────────────
info "Checking prerequisites..."
for cmd in gcloud terraform helm kubectl git docker; do
  command -v "$cmd" &>/dev/null || error "'$cmd' is not installed. Please install it and retry."
  info "  ✅ $cmd $(command -v $cmd)"
done

# ── Project ID ───────────────────────────────────────────────────────────────
if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  read -rp "Enter your GCP Project ID: " GCP_PROJECT_ID
fi
[[ -z "$GCP_PROJECT_ID" ]] && error "GCP_PROJECT_ID must be set."
export GCP_PROJECT_ID

# Validate project exists and we have access
gcloud projects describe "$GCP_PROJECT_ID" &>/dev/null \
  || error "Project '$GCP_PROJECT_ID' not found or no access."

gcloud config set project "$GCP_PROJECT_ID"
info "Working on project: $GCP_PROJECT_ID"

# ── Enable required APIs ─────────────────────────────────────────────────────
# Each API is required by at least one Terraform resource; enabling all up front
# avoids mid-apply failures that are hard to diagnose.
info "Enabling required GCP APIs (this takes ~2 minutes on first run)..."
gcloud services enable \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  dns.googleapis.com \
  cloudkms.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  compute.googleapis.com \
  binaryauthorization.googleapis.com \
  --project="$GCP_PROJECT_ID"
info "APIs enabled."

# ── GCS bucket for Terraform remote state ────────────────────────────────────
# State is stored in GCS so any machine (CI or local) shares the same lock and
# state file — prevents drift and concurrent-apply corruption.
TF_STATE_BUCKET="${GCP_PROJECT_ID}-tf-state"
info "Creating Terraform state bucket: gs://${TF_STATE_BUCKET}"
if gsutil ls -b "gs://${TF_STATE_BUCKET}" &>/dev/null; then
  warn "Bucket gs://${TF_STATE_BUCKET} already exists — skipping creation."
else
  gsutil mb -p "$GCP_PROJECT_ID" -l us-central1 "gs://${TF_STATE_BUCKET}"
  # Versioning lets us recover from accidental state deletions
  gsutil versioning set on "gs://${TF_STATE_BUCKET}"
  info "Bucket created with versioning enabled."
fi

# ── Terraform service account ─────────────────────────────────────────────────
TF_SA_NAME="terraform-sa"
TF_SA_EMAIL="${TF_SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
info "Creating Terraform service account: $TF_SA_EMAIL"

if gcloud iam service-accounts describe "$TF_SA_EMAIL" --project="$GCP_PROJECT_ID" &>/dev/null; then
  warn "Service account $TF_SA_EMAIL already exists — skipping creation."
else
  gcloud iam service-accounts create "$TF_SA_NAME" \
    --display-name="Terraform Automation SA" \
    --project="$GCP_PROJECT_ID"
fi

# Grant minimum required roles — no broader than necessary (principle of least privilege)
for role in \
  roles/container.admin \
  roles/compute.networkAdmin \
  roles/artifactregistry.admin \
  roles/secretmanager.admin \
  roles/iam.serviceAccountAdmin \
  roles/iam.workloadIdentityPoolAdmin \
  roles/resourcemanager.projectIamAdmin \
  roles/storage.admin \
  roles/binaryauthorization.policyEditor \
  roles/cloudkms.admin; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:${TF_SA_EMAIL}" \
    --role="$role" \
    --condition=None \
    --quiet
done
info "IAM roles granted to $TF_SA_EMAIL"

# Download key — stored outside the repo to prevent accidental commit
SA_KEY_DIR="${HOME}/.gcp"
SA_KEY_PATH="${SA_KEY_DIR}/terraform-sa-key.json"
mkdir -p "$SA_KEY_DIR"
if [[ -f "$SA_KEY_PATH" ]]; then
  warn "Key file $SA_KEY_PATH already exists — skipping download."
else
  gcloud iam service-accounts keys create "$SA_KEY_PATH" \
    --iam-account="$TF_SA_EMAIL" \
    --project="$GCP_PROJECT_ID"
  chmod 600 "$SA_KEY_PATH"
  info "Service account key saved to $SA_KEY_PATH"
fi
export GOOGLE_APPLICATION_CREDENTIALS="$SA_KEY_PATH"

# ── Billing budget alerts ─────────────────────────────────────────────────────
# Alert at $50 and $100 so we don't accidentally exhaust the $300 free trial.
BILLING_ACCOUNT=$(gcloud beta billing projects describe "$GCP_PROJECT_ID" \
  --format="value(billingAccountName)" | sed 's|billingAccounts/||')

if [[ -n "$BILLING_ACCOUNT" ]]; then
  info "Setting billing budget alerts on account: $BILLING_ACCOUNT"
  for AMOUNT in 50 100; do
    gcloud billing budgets create \
      --billing-account="$BILLING_ACCOUNT" \
      --display-name="devsecops-alert-${AMOUNT}usd" \
      --budget-amount="${AMOUNT}USD" \
      --threshold-rules=percent=0.9,basis=CURRENT_SPEND \
      2>/dev/null || warn "Could not create \$${AMOUNT} budget alert (may need billing API enabled or permissions)."
  done
else
  warn "No billing account linked — skipping budget alerts."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "  GCP Project Setup Complete"
echo "════════════════════════════════════════════════"
echo "  Project ID   : $GCP_PROJECT_ID"
echo "  TF State Bucket: gs://${TF_STATE_BUCKET}"
echo "  TF Service Account: $TF_SA_EMAIL"
echo "  SA Key: $SA_KEY_PATH"
echo ""
echo "  Next step:"
echo "    export GOOGLE_APPLICATION_CREDENTIALS=$SA_KEY_PATH"
echo "    export TF_VAR_project_id=$GCP_PROJECT_ID"
echo "    cd terraform/environments/staging"
echo "    terraform init && terraform apply"
echo "════════════════════════════════════════════════"
