#!/usr/bin/env bash
# port-forward.sh — Open port-forwards to all platform UIs in one command.
# Run this after ./scripts/deploy.sh to access dashboards on localhost.
# Use Ctrl+C to stop all port-forwards.
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }

info "Starting port-forwards for all platform UIs..."
info "Press Ctrl+C to stop all"

# Kill any existing port-forwards to avoid address-in-use errors
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

kubectl port-forward -n argocd    svc/argocd-server         8080:443  &
kubectl port-forward -n monitoring svc/prometheus-grafana    3000:80   &
kubectl port-forward -n monitoring svc/prometheus-operated   9090:9090 &
kubectl port-forward -n monitoring svc/loki-gateway          3100:80   &
kubectl port-forward -n security   svc/vault                 8200:8200 &
kubectl port-forward -n chaos-testing svc/chaos-dashboard    2333:2333 &
kubectl port-forward -n jenkins    svc/jenkins               8081:8080 &

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Platform UIs — all running on localhost"
echo "══════════════════════════════════════════════════════════"
echo "  ArgoCD       : https://localhost:8080  (admin / see deploy.sh output)"
echo "  Grafana      : http://localhost:3000   (admin / prom-operator)"
echo "  Prometheus   : http://localhost:9090"
echo "  Loki         : http://localhost:3100"
echo "  Vault        : http://localhost:8200"
echo "  Chaos Mesh   : http://localhost:2333"
echo "  Jenkins      : http://localhost:8081"
echo "══════════════════════════════════════════════════════════"
echo ""
echo "  Grafana dashboards to check:"
echo "    → Platform Overview"
echo "    → Service SLO Dashboard"
echo "    → GitOps Dashboard"
echo "    → Security Dashboard"
echo "    → Istio Traffic Dashboard"
echo ""

# Wait for all background jobs (keeps port-forwards alive until Ctrl+C)
wait
