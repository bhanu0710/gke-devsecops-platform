# Architecture Overview

## System Components

### Infrastructure Layer (Terraform)
| Component | Resource | Purpose |
|-----------|----------|---------|
| VPC | `google_compute_network` | Isolated network with custom subnets |
| GKE Cluster | `google_container_cluster` | Zonal Standard cluster, us-central1-a |
| Node Pool | `google_container_node_pool` | e2-medium Spot VMs, autoscaling 0-3 |
| Artifact Registry | `google_artifact_registry_repository` | Docker image storage |
| Secret Manager | `google_secret_manager_secret` | Runtime secrets (JWT key, API keys) |
| IAM / Workload Identity | `google_service_account` | Zero-credential pod authentication to GCP |
| KMS | `google_kms_crypto_key` | Cosign image signing + Vault auto-unseal |

### Application Layer (Helm + ArgoCD)
| Service | Language | Port | Purpose |
|---------|----------|------|---------|
| user-service | Node.js | 3000 | User CRUD, JWT authentication |
| product-service | Python FastAPI | 8000 | Product catalog |
| order-service | Node.js | 3001 | Order management, orchestrates user + product |

### GitOps Layer
- **ArgoCD** manages all Kubernetes resources via the app-of-apps pattern
- **Argo Rollouts** implements canary deployments with Prometheus-based auto-rollback
- Git is the single source of truth — no direct cluster mutations outside of git

### Security Layer
| Tool | Purpose |
|------|---------|
| Istio (Ambient) | mTLS between all services, AuthorizationPolicy |
| OPA Gatekeeper | Admission control (5 policies: no-latest, required-labels, resource-limits, no-root, registry-whitelist) |
| HashiCorp Vault | Dynamic secrets, PKI, KV store with GCP KMS auto-unseal |
| Falco | Runtime threat detection via eBPF syscall monitoring |
| Binary Authorization | Blocks unsigned images from being deployed |
| Cosign | Signs images in CI using GCP KMS key |

### Observability Layer
| Tool | Purpose |
|------|---------|
| Prometheus | Metrics collection, alerting rules, recording rules |
| Grafana | 5 dashboards: Platform Overview, SLO, GitOps, Security, Istio |
| Loki + FluentBit | Log aggregation with Kubernetes metadata enrichment |
| Grafana Tempo | Distributed tracing (OpenTelemetry → OTLP → Tempo) |
| Pyrra | SLO management, error budget tracking |
| KEDA | Event-driven autoscaling based on Prometheus metrics |

### Chaos Engineering
| Experiment | Tool | Tests |
|------------|------|-------|
| Pod kill | Chaos Mesh PodChaos | K8s self-healing, PDB, readiness probes |
| Network latency | Chaos Mesh NetworkChaos | Istio retries, circuit breaker |
| CPU stress | Chaos Mesh StressChaos | HPA scale-out |
| DNS failure | Chaos Mesh DNSChaos | Circuit breaker fast-fail |

## Data Flow: Creating an Order

```
User → NodePort → Istio Ingress Gateway
  → order-service (mTLS)
      → user-service (mTLS, AuthorizationPolicy verified)
      → product-service (mTLS, AuthorizationPolicy verified)
  → Response to User

Trace propagated via W3C traceparent header → visible in Grafana Tempo
```

## CI/CD Flow

```
Developer pushes code
  → GitHub Actions (lint, test, security scan)
  → Jenkins 9-stage pipeline:
      1. Checkout
      2. Dependency audit (npm audit / pip-audit)
      3. Unit tests + coverage (≥70%)
      4. SAST (SonarQube quality gate)
      5. Docker build (linux/amd64)
      6. Image scan (Trivy — blocks on CRITICAL/HIGH)
      7. Image sign (Cosign + GCP KMS)
      8. Push to Artifact Registry
      9. Update Helm values (git commit → triggers ArgoCD)
  → ArgoCD detects git change
  → Argo Rollouts canary: 10% → 30% → analysis → 100%
  → Prometheus analysis: if error rate > 5% → auto-rollback
```
