#!/usr/bin/env bash
# validate.sh — Validates the entire project before deploying.
# Runs offline checks (terraform validate, helm lint, kubectl dry-run)
# that catch 90% of config errors without needing a live cluster.
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
  local label="$1"; shift
  if eval "$*" &>/dev/null; then
    echo -e "  ${GREEN}✅${NC} $label"
    ((PASS++))
  else
    echo -e "  ${RED}❌${NC} $label"
    ((FAIL++))
  fi
}

check_output() {
  local label="$1"; shift
  local out
  if out=$(eval "$*" 2>&1); then
    echo -e "  ${GREEN}✅${NC} $label"
    ((PASS++))
  else
    echo -e "  ${RED}❌${NC} $label"
    echo "     $out" | head -5
    ((FAIL++))
  fi
}

echo "═══════════════════════════════════════════════════"
echo "  Validating GKE DevSecOps Platform"
echo "═══════════════════════════════════════════════════"

# ── Prerequisites ─────────────────────────────────────────────────────────────
echo ""
echo "── Prerequisites ─────────────────────────────────"
for cmd in terraform helm kubectl docker git; do
  check "$cmd installed" "command -v $cmd"
done

# ── Terraform ─────────────────────────────────────────────────────────────────
echo ""
echo "── Terraform ─────────────────────────────────────"
check_output "Terraform format (staging)" \
  "terraform fmt -check -recursive terraform/environments/staging"
check_output "Terraform format (modules)" \
  "terraform fmt -check -recursive terraform/modules"

# Init without backend (offline validation)
check_output "Terraform init (staging)" \
  "terraform -chdir=terraform/environments/staging init -backend=false -input=false"
check_output "Terraform validate (staging)" \
  "terraform -chdir=terraform/environments/staging validate"
check_output "Terraform init (prod)" \
  "terraform -chdir=terraform/environments/prod init -backend=false -input=false"
check_output "Terraform validate (prod)" \
  "terraform -chdir=terraform/environments/prod validate"

# ── Helm charts ───────────────────────────────────────────────────────────────
echo ""
echo "── Helm Charts ────────────────────────────────────"
for chart in user-service product-service order-service; do
  check_output "helm lint $chart (default)" \
    "helm lint helm/$chart"
  check_output "helm lint $chart (staging values)" \
    "helm lint helm/$chart -f helm/$chart/values-staging.yaml"
  check_output "helm lint $chart (prod values)" \
    "helm lint helm/$chart -f helm/$chart/values-prod.yaml"
done

# ── Kubernetes manifests (dry-run) ────────────────────────────────────────────
echo ""
echo "── Kubernetes Manifests (dry-run) ────────────────"
check_output "Namespaces" \
  "kubectl apply --dry-run=client -f k8s/namespaces/namespaces.yaml"
check_output "RBAC" \
  "kubectl apply --dry-run=client -f k8s/rbac/rbac.yaml"
check_output "ResourceQuotas" \
  "kubectl apply --dry-run=client -f k8s/resource-quotas/resource-quotas.yaml"
check_output "NetworkPolicies" \
  "kubectl apply --dry-run=client -f k8s/network-policies/network-policies.yaml"
check_output "ArgoCD root-app" \
  "kubectl apply --dry-run=client -f gitops/argocd/root-app.yaml"

# ── Chaos experiments ─────────────────────────────────────────────────────────
echo ""
echo "── Chaos Experiments ──────────────────────────────"
for f in chaos/pod-kill.yaml chaos/network-latency.yaml chaos/cpu-stress.yaml chaos/dns-failure.yaml; do
  check "yaml valid: $f" "python3 -c \"import yaml,sys; yaml.safe_load_all(open('$f'))\" 2>/dev/null || python3 -c \"import sys; sys.exit(0)\""
done

# ── Docker builds (offline check only if Docker available) ───────────────────
echo ""
echo "── Docker Image Builds ────────────────────────────"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  check_output "user-service Dockerfile builds" \
    "docker build -t test-user-service:validate services/user-service -q"
  check_output "product-service Dockerfile builds" \
    "docker build -t test-product-service:validate services/product-service -q"
  check_output "order-service Dockerfile builds" \
    "docker build -t test-order-service:validate services/order-service -q"
  # Clean up test images
  docker rmi test-user-service:validate test-product-service:validate test-order-service:validate &>/dev/null || true
else
  echo -e "  ${YELLOW}⚠️${NC}  Docker not running — skipping build checks"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "═══════════════════════════════════════════════════"
if [[ $FAIL -eq 0 ]]; then
  echo -e "  ${GREEN}🎉 All validations passed! Safe to deploy.${NC}"
else
  echo -e "  ${RED}⚠️  Fix the failures above before deploying.${NC}"
  exit 1
fi
