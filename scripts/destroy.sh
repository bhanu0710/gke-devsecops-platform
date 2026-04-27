#!/usr/bin/env bash
# destroy.sh — Scale cluster to zero to stop compute charges.
# The GKE control plane continues running (covered by the $74.40/month free tier credit).
# All K8s state (deployments, configmaps) is preserved — nodes come back with kubectl apply.
# Run this at end of day when you're done working to avoid spending free trial credit.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

[[ -z "${GCP_PROJECT_ID:-}" ]] && read -rp "GCP Project ID: " GCP_PROJECT_ID
CLUSTER_NAME="${CLUSTER_NAME:-devsecops-staging}"
ZONE="${ZONE:-us-central1-a}"

warn "This will scale all node pools to 0. Pods will be evicted. Confirm? (y/N)"
read -r CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { info "Aborted."; exit 0; }

info "Scaling node pool 'main-pool' to 0..."
gcloud container clusters resize "$CLUSTER_NAME" \
  --node-pool main-pool \
  --num-nodes 0 \
  --zone "$ZONE" \
  --project "$GCP_PROJECT_ID" \
  --quiet

info "Done. Cluster scaled to 0 nodes."
echo ""
echo "  GKE control plane: still running (free — covered by GKE credit)"
echo "  Node compute: \$0/hour until you scale back up"
echo "  Persistent disks: still exist (~\$0.04/GB/month)"
echo ""
echo "  To scale back up and redeploy:"
echo "    gcloud container clusters resize $CLUSTER_NAME --node-pool main-pool --num-nodes 1 --zone $ZONE"
echo "    ./scripts/deploy.sh"
echo ""
echo "  To fully destroy all infrastructure (irreversible):"
echo "    cd terraform/environments/staging && terraform destroy"
