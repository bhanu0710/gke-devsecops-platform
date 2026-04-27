#!/usr/bin/env bash
# setup-velero.sh — Install Velero for cluster backup and disaster recovery.
# Velero backs up K8s resources + PersistentVolume snapshots to GCS.
# Scheduled daily backup at 2am ensures RTO < 4 hours on full cluster loss.
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }

[[ -z "${GCP_PROJECT_ID:-}" ]] && read -rp "GCP Project ID: " GCP_PROJECT_ID
VELERO_BUCKET="${GCP_PROJECT_ID}-velero-backups"

# ── Create GCS backup bucket ──────────────────────────────────────────────────
info "Creating Velero GCS bucket: gs://${VELERO_BUCKET}"
gsutil mb -p "$GCP_PROJECT_ID" -l us-central1 "gs://${VELERO_BUCKET}" 2>/dev/null || \
  info "Bucket already exists — skipping"

# ── Create Velero service account ─────────────────────────────────────────────
VELERO_SA="velero-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
info "Creating Velero service account..."
gcloud iam service-accounts create velero-sa \
  --display-name="Velero Backup SA" \
  --project="$GCP_PROJECT_ID" 2>/dev/null || info "SA already exists"

# Grant GCS access for backup storage
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:${VELERO_SA}" \
  --role="roles/storage.objectAdmin" \
  --condition=None --quiet

# Workload Identity binding for Velero pod
gcloud iam service-accounts add-iam-policy-binding "$VELERO_SA" \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[velero/velero]"

# ── Install Velero via Helm ───────────────────────────────────────────────────
info "Installing Velero..."
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

helm upgrade --install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.provider=gcp \
  --set-json "configuration.backupStorageLocation[0].bucket=${VELERO_BUCKET}" \
  --set-json "configuration.backupStorageLocation[0].config.serviceAccount=${VELERO_SA}" \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"="${VELERO_SA}" \
  --set configuration.volumeSnapshotLocation[0].provider=gcp \
  --set snapshotsEnabled=true \
  --wait

# ── Create daily backup schedule ──────────────────────────────────────────────
info "Creating daily backup schedule (2am UTC, retain 7 days)..."
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --ttl 168h0m0s \
  --include-namespaces staging,prod,monitoring,security,argocd \
  2>/dev/null || info "Schedule already exists"

info "Velero installed. Verifying..."
velero backup-location get
velero schedule get

echo ""
echo "═══════════════════════════════════════════════"
echo "  Velero DR Setup Complete"
echo "  Backup bucket : gs://${VELERO_BUCKET}"
echo "  Schedule      : Daily at 2am UTC (7-day retention)"
echo "  Namespaces    : staging, prod, monitoring, security, argocd"
echo "═══════════════════════════════════════════════"
echo ""
echo "  To trigger a manual backup:"
echo "    velero backup create manual-\$(date +%Y%m%d) --include-namespaces staging"
echo ""
echo "  To restore from backup:"
echo "    velero restore create --from-backup <backup-name>"
echo "  See docs/runbooks/dr-recovery.md for the full procedure."
