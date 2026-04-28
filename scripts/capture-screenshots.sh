#!/usr/bin/env bash
# capture-screenshots.sh — Start all port-forwards and print capture instructions.
# Run this on your local machine; screenshots must be taken manually in the browser.
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}=== Starting port-forwards ===${NC}"
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

kubectl port-forward -n argocd    svc/argocd-server                    8080:443  2>/dev/null &
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana    3000:80   2>/dev/null &

sleep 3

echo ""
echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     SCREENSHOT CAPTURE GUIDE            ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════╝${NC}"
echo ""
echo "  ArgoCD: https://localhost:8080   (admin / see below)"
echo "  Grafana: http://localhost:3000   (admin / prom-operator)"
echo ""
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "<see deploy.sh output>")
echo -e "  ArgoCD password: ${GREEN}${ARGOCD_PASS}${NC}"
echo ""

echo -e "${YELLOW}[01] ArgoCD App-of-Apps${NC}"
echo "  URL: https://localhost:8080"
echo "  Click on 'root-app' → expand tree showing all 7 apps"
echo "  All apps should show: Synced + Healthy"
echo -e "  Save as: ${GREEN}docs/screenshots/01-argocd-app-of-apps.png${NC}"
echo ""

echo -e "${YELLOW}[02] Grafana — Services Overview${NC}"
echo "  URL: http://localhost:3000"
echo "  Navigate: Dashboards → Services Overview"
echo "  Generate some traffic first:"
echo "    kubectl port-forward -n staging svc/product-service-staging 18000:8000 &"
echo "    for i in \$(seq 30); do curl -s http://localhost:18000/products > /dev/null; done"
echo "  Capture: Request rate + p99 latency + pod restarts + CPU/memory panels"
echo -e "  Save as: ${GREEN}docs/screenshots/02-grafana-services-overview.png${NC}"
echo ""

echo -e "${YELLOW}[03] Grafana — Product Service Dashboard${NC}"
echo "  URL: http://localhost:3000"
echo "  Navigate: Dashboards → Product Service"
echo "  Capture: stat panels (req rate, error rate, p50/p99 latency) + endpoint breakdown"
echo -e "  Save as: ${GREEN}docs/screenshots/03-grafana-product-service.png${NC}"
echo ""

echo -e "${YELLOW}[04] Grafana — Node.js Services Dashboard${NC}"
echo "  URL: http://localhost:3000"
echo "  Navigate: Dashboards → Node.js Services (user + order)"
echo "  Capture: req rate + event loop lag + heap usage"
echo -e "  Save as: ${GREEN}docs/screenshots/04-grafana-nodejs-services.png${NC}"
echo ""

echo -e "${YELLOW}[05] GitHub Actions CI Pipeline${NC}"
echo "  URL: https://github.com/bhanu0710/gke-devsecops-platform/actions"
echo "  Click on a completed 'CI' workflow run"
echo "  Capture: all 5 jobs green (Lint, Unit Tests, Security Scan, Docker Build Check, Push)"
echo -e "  Save as: ${GREEN}docs/screenshots/05-github-actions-ci.png${NC}"
echo ""

echo -e "${YELLOW}[06] Chaos Pod-Kill Recovery${NC}"
echo "  Steps:"
echo "    1. Open http://localhost:3000 → Services Overview"
echo "    2. Enable Chaos Mesh first: helm upgrade platform helm/platform --set chaosMesh.enabled=true"
echo "    3. kubectl apply -f k8s/chaos/pod-kill-staging.yaml"
echo "    4. Watch 'Pod Restarts' panel spike then recover"
echo "    5. Screenshot at moment of recovery (spike + green return)"
echo "    6. kubectl delete -f k8s/chaos/pod-kill-staging.yaml"
echo -e "  Save as: ${GREEN}docs/screenshots/06-chaos-recovery.png${NC}"
echo ""

echo -e "${BOLD}=== DEMO VIDEO GUIDE ===${NC}"
echo ""
echo "Record a 5-minute screen recording covering:"
echo "  0:00-0:30  GitHub repo + README architecture overview"
echo "  0:30-1:30  GitHub Actions pipeline — show all 5 jobs green"
echo "  1:30-2:30  ArgoCD app-of-apps — all 7 apps Synced + Healthy"
echo "  2:30-3:30  Grafana Services Overview — live metrics"
echo "  3:30-4:30  Chaos pod-kill experiment — spike + recovery"
echo "  4:30-5:00  Product service dashboard — per-endpoint breakdown"
echo ""
echo "Upload to YouTube (unlisted), update README.md demo video section."
echo ""

wait
