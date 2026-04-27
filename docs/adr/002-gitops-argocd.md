# ADR-002: ArgoCD App-of-Apps over plain Helm or kubectl

**Status:** Accepted  
**Date:** 2024-01-15  
**Author:** Bhanu Pratap Singh

---

## Context

The platform has 6 application deployments (3 services × 2 environments) plus ~8 platform tools (Prometheus, Vault, Istio, Falco, Chaos Mesh, KEDA, Velero, Argo Rollouts). Deploying these manually with `helm install` or `kubectl apply` creates operational problems:

- No single source of truth for what's running on the cluster
- No drift detection — manual edits to the cluster are invisible
- Rollbacks require remembering what the previous state was
- New team members have no way to understand the current deployment state

---

## Decision

Use **ArgoCD with the App-of-Apps pattern** as the sole deployment mechanism. No direct `kubectl apply` or `helm install` in the deployment workflow — everything goes through git.

The structure:
```
root-app.yaml                     ← manually applied once
  └── gitops/argocd/applications/ ← ArgoCD watches this directory
        ├── user-service-staging.yaml
        ├── user-service-prod.yaml
        ├── product-service-staging.yaml
        ├── product-service-prod.yaml
        ├── order-service-staging.yaml
        ├── order-service-prod.yaml
        └── platform-tools.yaml
```

**Why Argo Rollouts** for canary deployments instead of ArgoCD's built-in sync waves: Rollouts provides a Prometheus-based `AnalysisTemplate` that automatically rolls back if error rate > 5%. ArgoCD's sync waves don't support automated rollback based on metrics.

---

## Consequences

### Positive
- **Declarative** — the git repository is the authoritative state of the cluster. `git log` is the deployment history.
- **Self-healing** — `selfHeal: true` means ArgoCD continuously reconciles. Manual cluster edits are automatically reverted within 3 minutes.
- **Audit trail** — every deployment is a git commit with author, timestamp, and change diff
- **Drift detection** — ArgoCD alerts when cluster state diverges from git (e.g., someone ran `kubectl edit deployment`)
- **App-of-Apps scales** — adding a new service requires one YAML file in `gitops/argocd/applications/`; ArgoCD discovers and deploys it automatically

### Negative
- **Learning curve** — ArgoCD adds operational complexity. Debugging a failed sync requires understanding ArgoCD's sync phases and resource health checks.
- **Bootstrap chicken-and-egg** — ArgoCD itself cannot be deployed by ArgoCD. The initial `kubectl apply -f gitops/argocd/root-app.yaml` must be done manually (documented in `scripts/deploy.sh`).
- **Webhook dependency** — for instant sync on push (vs 3-minute polling), GitHub webhooks must be configured. Not a blocker but worth noting.

### Neutral
- Argo Rollouts CRDs replace Kubernetes `Deployment` resources for the 3 microservices. This is a well-supported pattern but means `kubectl rollout` commands no longer apply — use `kubectl argo rollouts` instead.
