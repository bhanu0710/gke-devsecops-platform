# GKE DevSecOps Platform

<p align="center">
  <img src="docs/screenshots/01-argocd-app-of-apps.png" alt="ArgoCD App-of-Apps showing all services in sync" width="800"/>
</p>

> A production-grade DevSecOps platform on Google Kubernetes Engine demonstrating
> IaC, GitOps, CI/CD, Observability, and Chaos Engineering in one cohesive system.
> Built by **Bhanu Pratap Singh** as a portfolio project.

[![CI](https://github.com/bhanu0710/gke-devsecops-platform/actions/workflows/ci.yaml/badge.svg)](https://github.com/bhanu0710/gke-devsecops-platform/actions/workflows/ci.yaml)
[![Terraform](https://img.shields.io/badge/Terraform-v1.6%2B-7B42BC?logo=terraform)](terraform/)
[![GKE](https://img.shields.io/badge/GKE-Standard-4285F4?logo=google-cloud)](https://cloud.google.com/kubernetes-engine)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)](gitops/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Monthly Cost](https://img.shields.io/badge/Monthly_Cost-~%2420-brightgreen)](#cost)

---

## What this demonstrates

| Discipline | Tools & Techniques |
|------------|-------------------|
| **Infrastructure as Code** | Terraform modules (VPC, GKE, Artifact Registry, IAM, Secret Manager) |
| **GitOps** | ArgoCD App-of-Apps pattern — all services auto-sync from Git |
| **CI/CD** | GitHub Actions: lint → test → Trivy scan → build → push → Helm tag bump |
| **DevSecOps** | Trivy image scanning, Binary Authorization, OPA Gatekeeper, Cosign signing |
| **Observability** | Prometheus + 3 Grafana dashboards, OpenTelemetry distributed tracing |
| **Chaos Engineering** | Chaos Mesh pod-kill + network-delay experiments with Grafana recovery graphs |
| **Cost Engineering** | Spot VMs, scale-to-zero, NodePort only (no $18/mo load balancer) |
| **Multi-environment** | Separate staging + prod namespaces, per-env resource tuning |
| **Security** | Workload Identity Federation (zero JSON keys), non-root containers, read-only FS |

---

## Architecture

```
GitHub (main branch)
        │  push
        ▼
GitHub Actions CI ──────────────────────────────────────────────────────────┐
  [lint] [test ≥70% cov] [trivy scan] [docker build/push] [helm tag bump]  │
        │                                                     tag commit     │
        ▼                                                          ▼         │
Artifact Registry ◄── images ──────────── ArgoCD (App-of-Apps) ◄──── Git   │
us-central1-docker.pkg.dev                       │                          │
                                                 │ deploys                  │
                                    ┌────────────┴────────────┐             │
                                    ▼                         ▼             │
                               staging ns                  prod ns          │
                          user-service :3000          user-service :3000    │
                          order-service :3001         order-service :3001   │
                          product-service :8000       product-service :8000 │
                                    │                                       │
                                    ▼                                       │
                           monitoring ns                                    │
                     Prometheus ──► Grafana                                 │
                     (3 dashboards: services overview,                      │
                      product-service, node.js services)                    │
                                                                            │
GKE Cluster (us-central1-a, 3× e2-medium spot VMs)                        │
  Workload Identity ──► GCP Secret Manager (jwt-secret, db-password)       │
  Binary Authorization ──► only signed images from Artifact Registry       │
  OPA Gatekeeper ──► enforce resource limits + non-root containers         │
```

---

## CI Pipeline (GitHub Actions)

Every push to `main` triggers:

```
lint ──► test ──► trivy-scan ──► build-check   (parallel)
                                      │
                              push + tag-bump  (main only, needs all above)
                                      │
                              ArgoCD auto-sync ──► pods rolling-update
```

**Security gates in CI:**
- `ruff` (Python) + `eslint` (Node.js) — linting
- `pytest` / `jest` with ≥70% coverage threshold
- Trivy config scan — blocks on HIGH/CRITICAL Dockerfile issues
- OWASP dependency check on PRs
- Checkov IaC scan on Terraform changes

---

## Services

| Service | Language | Port | Key endpoints |
|---------|----------|------|---------------|
| **user-service** | Node.js 20 | 3000 | `POST /users`, `POST /auth/login`, `GET /health`, `GET /metrics` |
| **order-service** | Node.js 20 | 3001 | `POST /orders`, `GET /orders/:id`, `GET /health`, `GET /metrics` |
| **product-service** | Python FastAPI | 8000 | `GET /products`, `POST /products`, `GET /health`, `GET /metrics` |

All services expose `/metrics` for Prometheus scraping and use OpenTelemetry for distributed tracing to Grafana Tempo.

---

## Chaos Engineering

Two experiment types ready in `k8s/chaos/`:

| Experiment | Effect | Purpose |
|------------|--------|---------|
| `pod-kill-staging.yaml` | Kills one product-service pod every 2 min | Verifies Deployment self-healing + Prometheus restart counter |
| `network-delay-staging.yaml` | Injects 200ms latency on order-service for 5 min | Shows p99 latency spike + recovery on Grafana dashboard |

```bash
# Enable Chaos Mesh first (requires cluster headroom)
helm upgrade platform helm/platform --set chaosMesh.enabled=true

# Run pod-kill experiment
kubectl apply -f k8s/chaos/pod-kill-staging.yaml

# Watch recovery in Grafana → Services Overview → Pod Restarts panel
# Stop experiment
kubectl delete -f k8s/chaos/pod-kill-staging.yaml
```

---

## Screenshots

<details>
<summary>Platform screenshots</summary>

| | |
|--|--|
| ![ArgoCD App-of-Apps](docs/screenshots/01-argocd-app-of-apps.png) | ![Services Overview](docs/screenshots/02-grafana-services-overview.png) |
| **ArgoCD — All 6 apps Synced + Healthy** | **Grafana — Services Overview Dashboard** |
| ![Product Service](docs/screenshots/03-grafana-product-service.png) | ![Node.js Services](docs/screenshots/04-grafana-nodejs-services.png) |
| **Grafana — Product Service (Python FastAPI)** | **Grafana — Node.js Services Dashboard** |
| ![CI Pipeline](docs/screenshots/05-github-actions-ci.png) | ![Chaos Recovery](docs/screenshots/06-chaos-recovery.png) |
| **GitHub Actions — Full pipeline green** | **Grafana — Chaos pod-kill recovery** |

</details>

---

## Cost

| Resource | Monthly Cost |
|----------|-------------|
| GKE Control Plane | **$0** (free during $300 trial) |
| e2-medium Spot Nodes × 3 (active) | ~$18/month |
| Artifact Registry | ~$0.10/month |
| Cloud Storage (TF state) | ~$0.50/month |
| Secret Manager | ~$0.06/month |
| **Total (active development)** | **~$20/month** |
| **Total project spend** | **< $220 (within $300 trial)** |

**Cost controls:**
- `terraform destroy` when not developing → $0 compute
- Spot VMs (preemptible) → 60-90% cheaper than on-demand
- NodePort ingress only → no $18/month HTTP load balancer
- Zero JSON credential keys → no Secret Manager secret rotation cost

---

## Quick Start

```bash
# Prerequisites: gcloud, terraform ≥1.6, helm ≥3.14, kubectl, git, docker

git clone https://github.com/bhanu0710/gke-devsecops-platform
cd gke-devsecops-platform

# 1. Bootstrap GCP project (enable APIs, TF state bucket, service accounts)
./scripts/setup.sh

# 2. Provision infrastructure (~8 min)
cd terraform/environments/staging
terraform init -backend-config="bucket=dev-project-494110-tf-state"
terraform apply
cd ../../..

# 3. Bootstrap ArgoCD + all applications
./scripts/deploy.sh

# 4. Access UIs
kubectl port-forward -n argocd    svc/argocd-server      8080:443   &
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
# ArgoCD:  https://localhost:8080  (admin / get password below)
# Grafana: http://localhost:3000   (admin / prom-operator)

# Get ArgoCD initial password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# 5. Scale to zero when done (stops compute charges)
gcloud container clusters resize devsecops-staging \
  --node-pool main-pool --num-nodes 0 --zone us-central1-a
```

---

## Repository Structure

```
.
├── .github/workflows/   # CI: ci.yaml (lint+test+build+push), pr-checks.yaml, validate-terraform.yaml
├── terraform/           # IaC: VPC, GKE cluster, Artifact Registry, IAM, Secret Manager
│   ├── modules/         #   → vpc, gke, iam, artifact-registry, secret-manager
│   └── environments/    #   → staging, prod
├── services/            # 3 microservices
│   ├── user-service/    #   Node.js 20 — JWT auth, bcrypt, Prometheus, OTel
│   ├── product-service/ #   Python FastAPI — Pydantic, Prometheus, OTel
│   └── order-service/   #   Node.js 20 — calls user+product, Prometheus, OTel
├── helm/                # Helm charts
│   ├── library-chart/   #   Shared Deployment/Service/HPA/PDB/ServiceMonitor template
│   ├── user-service/    #   Per-service chart (values.yaml + values-staging.yaml + values-prod.yaml)
│   ├── product-service/ #
│   ├── order-service/   #
│   └── platform/        #   Umbrella chart: Chaos Mesh (disabled by default)
├── gitops/              # ArgoCD
│   └── argocd/
│       ├── root-app.yaml          # App-of-Apps root
│       └── applications/          # 7 Application manifests
├── k8s/                 # Raw Kubernetes manifests
│   ├── system/          #   DaemonSets (spot-taint-remover)
│   ├── chaos/           #   Chaos Mesh experiments
│   └── monitoring/      #   Grafana dashboard ConfigMaps
└── scripts/             # setup.sh, deploy.sh
```

---

## Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| **Cluster topology** | Zonal (us-central1-a) | Free tier — regional clusters cost 3× |
| **Node type** | e2-medium Spot VMs | 60-90% cheaper; workloads are stateless |
| **Ingress** | NodePort only | GCP HTTP LB costs $18/month fixed |
| **Image registry** | Artifact Registry | Native GCP WIF auth, no credentials needed |
| **Secrets** | Workload Identity + Secret Manager | Zero JSON keys committed anywhere |
| **Helm deps** | Bundle `charts/*.tgz` in git | ArgoCD can't resolve `file://` local deps |
| **Python deps** | `python -m venv` in Dockerfile | `pip install --target` breaks `pkg_resources` |
| **Deployment selector** | `app` label only, no `version` | Selector is immutable — version tag breaks updates |

---

## Author

**Bhanu Pratap Singh**  
DevOps & Cloud Engineer | Mumbai, India

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Bhanu_Pratap_Singh-0077B5?logo=linkedin)](https://linkedin.com/in/bhanu0710)
[![GitHub](https://img.shields.io/badge/GitHub-bhanu0710-181717?logo=github)](https://github.com/bhanu0710)

---

*Every configuration choice is intentional and documented in commit messages and inline comments.*
