# Cost Optimization

## Philosophy

This project demonstrates that a production-realistic Kubernetes platform can run for **< $1/month** at idle and **~$20/month** during active development — entirely within GCP's $300 free trial.

## Cost Breakdown

### Before optimization (naive setup)

| Resource | Naive config | Cost/month |
|----------|-------------|-----------|
| GKE Control Plane | Regional cluster | $74.40 |
| HTTP(S) Load Balancer | Managed ingress | $18.26 |
| e2-standard-4 on-demand | 3 nodes | ~$145 |
| **Total** | | **~$237/month** |

### After optimization (this project)

| Resource | Optimized config | Cost/month |
|----------|-----------------|-----------|
| GKE Control Plane | Zonal cluster + free tier credit | **$0** |
| Ingress | NodePort (no LB) | **$0** |
| e2-medium Spot VMs | Scale-to-zero at night | **$0 idle / ~$18 active** |
| Artifact Registry | ~5GB images | ~$0.50 |
| Cloud Storage | TF state + Velero + Loki | ~$0.80 |
| Secret Manager | 5 secrets × 10K accesses | ~$0.06 |
| Cloud KMS | 1 key version (free tier) | $0 |
| **Total (idle)** | | **~$1.36/month** |
| **Total (active 8h/day)** | | **~$20/month** |

## Key Decisions

### 1. Zonal vs Regional GKE cluster
GKE's `$74.40/month` credit applies to the control plane. A **zonal** cluster has 1 control plane replica (fully covered by the credit). A **regional** cluster has 3 replicas — the credit only covers 1, costing `2 × $74.40 × 0.10 = $14.88/month` extra.

### 2. NodePort instead of Cloud Load Balancer
GCP's HTTP(S) Load Balancer costs $18.26/month as a baseline (before traffic charges). For a portfolio project accessed via `kubectl port-forward`, this cost is entirely avoidable. All UIs are accessible locally via `./scripts/port-forward.sh`.

### 3. Spot VMs
e2-medium Spot VMs cost ~70% less than on-demand. Spot nodes can be preempted at any time — acceptable for stateless demo workloads. The Kubernetes scheduler + PodDisruptionBudget ensures at least 1 replica stays available during evictions.

### 4. Scale-to-zero
`min_node_count = 0` in the node pool autoscaler config allows the pool to scale to 0 nodes when idle. Running `./scripts/destroy.sh` scales to 0 nodes — the control plane continues running (covered by free tier) but compute charges drop to $0.

### 5. Google Managed Prometheus
Instead of running self-managed Prometheus (needs a persistent disk and dedicated pods), GKE's built-in Google Managed Prometheus is free up to 150M samples/month — sufficient for a 3-service demo.

## Actual Project Spend

| Phase | Approximate spend |
|-------|------------------|
| Phase 1-2 (Terraform + GKE + services) | ~$20 |
| Phase 3-5 (GitOps + Security + Observability) | ~$40 |
| Phase 6-7 (Chaos + docs + testing) | ~$30 |
| Ongoing active development (6 weeks) | ~$120 |
| **Total** | **~$210** |

Well within the $300 trial limit. ~$90 remaining for further experimentation.
