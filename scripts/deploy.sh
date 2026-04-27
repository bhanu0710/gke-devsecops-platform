#!/usr/bin/env bash
# deploy.sh — Bootstrap the full platform after Terraform has provisioned GKE.
# Run once after `terraform apply` to install ArgoCD and the root app-of-apps.
# After that, all further deployments happen via git push (GitOps).
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ -z "${GCP_PROJECT_ID:-}" ]] && read -rp "GCP Project ID: " GCP_PROJECT_ID
[[ -z "${CLUSTER_NAME:-}" ]] && CLUSTER_NAME="devsecops-staging"
[[ -z "${ZONE:-}" ]] && ZONE="us-central1-a"

info "Configuring kubectl for cluster: $CLUSTER_NAME"
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE" --project "$GCP_PROJECT_ID"

# ── Namespaces ────────────────────────────────────────────────────────────────
info "Creating namespaces..."
kubectl apply -f k8s/namespaces/namespaces.yaml

# ── ArgoCD ────────────────────────────────────────────────────────────────────
info "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

info "Waiting for ArgoCD to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# Change ArgoCD service to NodePort (avoids LoadBalancer cost)
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30080}]}}'

ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 --decode)
info "ArgoCD initial admin password: $ARGOCD_PASSWORD"
echo "  Save this → you need it at https://NODE_IP:30080"

# ── Argo Rollouts ─────────────────────────────────────────────────────────────
info "Installing Argo Rollouts..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# ── Deploy root app-of-apps ───────────────────────────────────────────────────
# This single kubectl apply bootstraps the entire platform.
# ArgoCD takes over from here — it reads the git repo and creates all other apps.
info "Applying root app-of-apps..."
kubectl apply -f gitops/argocd/root-app.yaml

info "Applying ArgoCD project..."
kubectl apply -f gitops/argocd/projects/platform-project.yaml

# ── RBAC + Network Policies ───────────────────────────────────────────────────
info "Applying RBAC and network policies..."
kubectl apply -f k8s/rbac/rbac.yaml
kubectl apply -f k8s/network-policies/network-policies.yaml
kubectl apply -f k8s/resource-quotas/resource-quotas.yaml

# ── Summary ───────────────────────────────────────────────────────────────────
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Platform Bootstrap Complete"
echo "════════════════════════════════════════════════════════════"
echo "  ArgoCD UI: https://${NODE_IP}:30080"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "  ArgoCD will now sync the git repo and deploy all services."
echo "  Run ./scripts/port-forward.sh to access all UIs locally."
echo "════════════════════════════════════════════════════════════"
