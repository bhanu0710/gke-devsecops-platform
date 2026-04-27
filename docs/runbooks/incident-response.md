# Runbook: Incident Response

**Severity levels:** P0 (site down) | P1 (degraded) | P2 (partial impairment) | P3 (minor)

---

## Alert: HighErrorRate (P1)

**Trigger:** `job:request_error_rate:ratio_rate5m > 0.05` for 5 minutes

### Diagnosis steps

```bash
# 1. Check which service is failing
kubectl top pods -n staging
kubectl get pods -n staging -l app=<service>

# 2. Check recent pod restarts
kubectl get events -n staging --sort-by='.lastTimestamp' | tail -20

# 3. Check application logs via Loki
# In Grafana: Explore → Loki → {namespace="staging",app="<service>"} | json | level="error"

# 4. Check if it's an upstream dependency issue
kubectl logs -n staging -l app=order-service --tail=50 | grep "Upstream error"

# 5. Check if a bad canary rollout is the cause
kubectl argo rollouts get rollout order-service -n staging
```

### Remediation

```bash
# If canary rollout is causing errors — immediate rollback
kubectl argo rollouts abort order-service -n staging

# If pod is crash-looping — check resource limits
kubectl describe pod <pod-name> -n staging | grep -A5 "Limits\|OOMKilled"

# If upstream dependency (user-service) is down — order-service circuit breaker should kick in
# Verify circuit breaker state in Grafana → Istio Traffic Dashboard

# Force ArgoCD to re-sync (if config drift is suspected)
argocd app sync order-service-staging --force
```

---

## Alert: PodCrashLooping (P2)

```bash
# Check exit code and OOM kills
kubectl describe pod <pod-name> -n staging
kubectl logs <pod-name> -n staging --previous  # logs from crashed container

# Common causes:
# Exit code 137 = OOMKilled → increase memory limit in helm/*/values-staging.yaml
# Exit code 1   = application error → check logs above
# Exit code 126/127 = permission/binary issue → check Dockerfile
```

---

## Alert: ArgoCDAppOutOfSync (P3)

```bash
# Check why it's out of sync
argocd app diff <app-name>

# Force resync
argocd app sync <app-name> --prune

# If selfHeal keeps reverting a manual change you want to keep:
# Update the git repo to match the desired state, then push
```

---

## Spot Node Preemption

Spot VMs can be preempted at any time by GCP. This is expected behavior.

```bash
# Check which node was preempted
kubectl get nodes
kubectl describe node <node-name> | grep -A5 "Conditions\|Taint"

# The cluster autoscaler should automatically provision a replacement.
# If it doesn't within 5 minutes:
gcloud container clusters resize devsecops-staging \
  --node-pool main-pool --num-nodes 1 --zone us-central1-a

# Check pods are rescheduled
kubectl get pods -n staging -o wide
```
