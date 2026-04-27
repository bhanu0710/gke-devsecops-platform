#!/usr/bin/env bash
# capture-screenshots.sh — Step-by-step guide for capturing all demo screenshots.
# Screenshots cannot be taken automatically, but this script starts all port-forwards
# and prints exactly what to capture and where to save each file.
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}=== Starting port-forwards for all UIs ===${NC}"

pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

kubectl port-forward -n argocd    svc/argocd-server       8080:443  2>/dev/null &
kubectl port-forward -n monitoring svc/prometheus-grafana  3000:80   2>/dev/null &
kubectl port-forward -n jenkins    svc/jenkins             8081:8080 2>/dev/null &
kubectl port-forward -n chaos-testing svc/chaos-dashboard  2333:2333 2>/dev/null &

sleep 3

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         SCREENSHOT CAPTURE GUIDE                       ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}[01] ArgoCD App-of-Apps${NC}"
echo "  URL: https://localhost:8080"
echo "  Login: admin / (see deploy.sh output)"
echo "  What to capture: Expand the root-app tree showing all 6 service apps + platform-tools"
echo "  All apps should show: Synced + Healthy (green)"
echo -e "  Save as: ${GREEN}docs/screenshots/01-argocd-app-of-apps.png${NC}"
echo ""

echo -e "${YELLOW}[02] Grafana Platform Overview${NC}"
echo "  URL: http://localhost:3000"
echo "  Login: admin / prom-operator"
echo "  Navigate: Dashboards → Platform Overview"
echo "  What to capture: Full dashboard showing pod count, CPU/memory gauges, request rate"
echo -e "  Save as: ${GREEN}docs/screenshots/02-grafana-platform-overview.png${NC}"
echo ""

echo -e "${YELLOW}[03] SLO Dashboard${NC}"
echo "  URL: http://localhost:3000"
echo "  Navigate: Dashboards → Service SLO Dashboard"
echo "  What to capture: All 3 services showing ≥99.9% availability + error budget bars"
echo -e "  Save as: ${GREEN}docs/screenshots/03-grafana-slo-dashboard.png${NC}"
echo ""

echo -e "${YELLOW}[04] Distributed Trace (order-service → user + product)${NC}"
echo "  URL: http://localhost:3000"
echo "  Navigate: Explore → Data source: Tempo → Search"
echo "  Send a test order: curl -X POST http://NODE_IP:NODE_PORT/orders ..."
echo "  Find the trace → expand to see 3-service span tree"
echo -e "  Save as: ${GREEN}docs/screenshots/04-grafana-trace.png${NC}"
echo ""

echo -e "${YELLOW}[05] Loki Log Query${NC}"
echo "  URL: http://localhost:3000"
echo "  Navigate: Explore → Data source: Loki"
echo "  Query: {namespace=\"staging\",app=\"order-service\"} | json"
echo "  What to capture: Live log stream with Kubernetes labels visible"
echo -e "  Save as: ${GREEN}docs/screenshots/05-grafana-loki-logs.png${NC}"
echo ""

echo -e "${YELLOW}[06] Istio Traffic Topology${NC}"
echo "  URL: http://localhost:3000"
echo "  Navigate: Dashboards → Istio Traffic Dashboard"
echo "  What to capture: Service mesh showing order→user and order→product arrows with request rates"
echo -e "  Save as: ${GREEN}docs/screenshots/06-istio-topology.png${NC}"
echo ""

echo -e "${YELLOW}[07] Jenkins Pipeline (all 9 stages green)${NC}"
echo "  URL: http://localhost:8081"
echo "  Navigate: gke-devsecops-platform → last successful build → Stage View"
echo "  What to capture: Blue ocean or Stage View showing all 9 stages with green checkmarks"
echo -e "  Save as: ${GREEN}docs/screenshots/07-jenkins-pipeline-success.png${NC}"
echo ""

echo -e "${YELLOW}[08] Chaos Pod Kill Recovery${NC}"
echo "  Steps:"
echo "    1. Open Grafana Platform Overview in one window"
echo "    2. Run: kubectl apply -f chaos/pod-kill.yaml"
echo "    3. Watch the error rate spike in Grafana, then recover to 0%"
echo "    4. Screenshot at the moment of recovery (spike visible + back to green)"
echo -e "  Save as: ${GREEN}docs/screenshots/08-chaos-pod-kill-recovery.png${NC}"
echo ""

echo -e "${BOLD}=== DEMO VIDEO GUIDE ===${NC}"
echo ""
echo "Record a 5-minute screen recording covering:"
echo "  0:00-0:30  GitHub repo — architecture diagram in README"
echo "  0:30-1:30  Make a code change → push → Jenkins pipeline running all 9 stages"
echo "  1:30-2:30  ArgoCD detecting the git change → canary rollout starting"
echo "  2:30-3:30  Grafana: traffic shifting 10% → 30% → 100% on the canary"
echo "  3:30-4:30  Run pod-kill chaos → show Grafana spike and recovery"
echo "  4:30-5:00  SLO dashboard — error budget still healthy"
echo ""
echo "Upload to YouTube (unlisted) and replace YOUTUBE_ID in README.md"
echo ""

wait
