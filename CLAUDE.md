# GKE DevSecOps Platform — Claude Code Context

## Project
Production-grade DevSecOps platform on GKE for portfolio/job search purposes.
Owner: Bhanu Pratap Singh | DevOps Engineer | Mumbai, India

## Tech stack
- IaC: Terraform (google provider ~5.x)
- Orchestration: GKE Standard, zonal (us-central1-a)
- GitOps: ArgoCD + Argo Rollouts
- CI: Jenkins (in-cluster) + GitHub Actions + Cloud Build
- Security: Vault, Istio, OPA Gatekeeper, Falco, Binary Authorization, Cosign/Trivy
- Observability: Prometheus, Grafana, Loki, Tempo, OpenTelemetry
- Chaos: Chaos Mesh
- Services: Node.js (user, order), Python FastAPI (product)

## Key constraints
- GCP free trial ($300 credit). Use zonal cluster (us-central1-a) for free tier credit.
- Spot VMs for all node pools (min=0 for scale-to-zero)
- NodePort ingress ONLY — never use GCP HTTP(S) Load Balancer (costs $18/mo)
- All secrets via Workload Identity + Secret Manager. ZERO static credentials in code.
- Always run `terraform fmt` and `terraform validate` before committing IaC.
- Always run `helm lint` before committing Helm charts.

## Commit style
feat: <what was built>
fix: <what was fixed>
docs: <what was documented>
chore: <maintenance task>

## Build order
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 (docs/README)
Never skip validation between phases.
