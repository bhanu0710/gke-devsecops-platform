# Screenshots

This directory holds the 8 demo screenshots referenced in the main README.

Run `./scripts/capture-screenshots.sh` for step-by-step instructions on capturing each one.

| File | Dashboard | What to show |
|------|-----------|--------------|
| `01-argocd-app-of-apps.png` | ArgoCD | Root app expanded, all 6 service apps + platform-tools — all green |
| `02-grafana-platform-overview.png` | Grafana | Pod count, CPU/memory gauges, request rate timeseries |
| `03-grafana-slo-dashboard.png` | Grafana | All 3 services at ≥99.9% availability + error budget bars |
| `04-grafana-trace.png` | Grafana Tempo | Single order request showing 3-service span tree |
| `05-grafana-loki-logs.png` | Loki | Live log stream with namespace/pod labels visible |
| `06-istio-topology.png` | Grafana | Istio traffic dashboard showing order→user, order→product arrows |
| `07-jenkins-pipeline-success.png` | Jenkins | Stage View with all 9 stages showing green checkmarks |
| `08-chaos-pod-kill-recovery.png` | Grafana | Platform Overview: brief error spike then recovery to 0% |
