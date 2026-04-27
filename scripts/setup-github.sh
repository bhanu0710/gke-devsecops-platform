#!/usr/bin/env bash
# setup-github.sh — Create the GitHub repo and configure all secrets for CI.
# Run once after the GCP setup is complete.
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }

command -v gh &>/dev/null || { echo "Install GitHub CLI: https://cli.github.com"; exit 1; }
gh auth status &>/dev/null || { echo "Run: gh auth login"; exit 1; }

REPO_NAME="gke-devsecops-platform"
GITHUB_USER=$(gh api user --jq '.login')

info "Creating public GitHub repository: $GITHUB_USER/$REPO_NAME"
gh repo create "$REPO_NAME" \
  --public \
  --description "Production-grade DevSecOps platform on GKE — Terraform, ArgoCD, Istio, Prometheus, Vault, Chaos Engineering" \
  --homepage "https://github.com/$GITHUB_USER/$REPO_NAME" \
  2>/dev/null || info "Repository already exists — updating..."

# Add topics so the repo is discoverable
gh repo edit "$GITHUB_USER/$REPO_NAME" \
  --add-topic "devops" \
  --add-topic "kubernetes" \
  --add-topic "gke" \
  --add-topic "terraform" \
  --add-topic "argocd" \
  --add-topic "devsecops" \
  --add-topic "gitops" \
  --add-topic "chaos-engineering" \
  --add-topic "prometheus" \
  --add-topic "istio" \
  --add-topic "portfolio" 2>/dev/null || true

# ── GitHub Secrets for CI ─────────────────────────────────────────────────────
# These secrets are referenced in ci/.github/workflows/ci.yaml
info "Setting GitHub secrets for CI..."

[[ -z "${GCP_PROJECT_ID:-}" ]] && read -rp "GCP Project ID: " GCP_PROJECT_ID
[[ -z "${WIF_PROVIDER:-}" ]] && read -rp "Workload Identity Provider (projects/NUM/locations/global/workloadIdentityPools/...): " WIF_PROVIDER
[[ -z "${CI_SA_EMAIL:-}" ]] && read -rp "CI Service Account email (jenkins-sa@...): " CI_SA_EMAIL
[[ -z "${SONAR_TOKEN:-}" ]] && read -rp "SonarQube token (or press Enter to skip): " SONAR_TOKEN
[[ -z "${SLACK_WEBHOOK:-}" ]] && read -rp "Slack webhook URL (or press Enter to skip): " SLACK_WEBHOOK

gh secret set GCP_PROJECT_ID --body "$GCP_PROJECT_ID" --repo "$GITHUB_USER/$REPO_NAME"
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body "$WIF_PROVIDER" --repo "$GITHUB_USER/$REPO_NAME"
gh secret set GCP_SERVICE_ACCOUNT --body "$CI_SA_EMAIL" --repo "$GITHUB_USER/$REPO_NAME"
[[ -n "$SONAR_TOKEN" ]] && gh secret set SONAR_TOKEN --body "$SONAR_TOKEN" --repo "$GITHUB_USER/$REPO_NAME"
[[ -n "$SLACK_WEBHOOK" ]] && gh secret set SLACK_WEBHOOK --body "$SLACK_WEBHOOK" --repo "$GITHUB_USER/$REPO_NAME"

# Set repo variables (not secrets)
gh variable set GCP_PROJECT_ID --body "$GCP_PROJECT_ID" --repo "$GITHUB_USER/$REPO_NAME" 2>/dev/null || true

# ── Push to GitHub ────────────────────────────────────────────────────────────
info "Pushing code to GitHub..."
git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git" 2>/dev/null || \
  git remote set-url origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
git branch -M main
git push -u origin main --tags

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  GitHub Repository Setup Complete"
echo "  URL: https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "  Add to your LinkedIn profile:"
echo "  'GKE DevSecOps Platform — github.com/$GITHUB_USER/$REPO_NAME'"
echo "═══════════════════════════════════════════════════════"
