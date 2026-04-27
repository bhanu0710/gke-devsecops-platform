# Runbook: Disaster Recovery

**RTO target:** < 4 hours (full cluster loss scenario)  
**RPO target:** < 24 hours (last successful Velero backup)  
**Tested:** Quarterly

---

## Scenario: Full cluster loss (zone failure or accidental terraform destroy)

### Prerequisites
- GCS backup bucket exists: `gs://${GCP_PROJECT_ID}-velero-backups`
- Velero backup from previous 24h exists
- GCP credentials available locally

### Step 1: Re-provision the cluster

```bash
# Ensure GCP credentials are set
export GOOGLE_APPLICATION_CREDENTIALS=~/.gcp/terraform-sa-key.json
export TF_VAR_project_id=<your-project-id>

# Re-apply Terraform (uses the same GCS state — idempotent)
cd terraform/environments/staging
terraform init -backend-config="bucket=${TF_VAR_project_id}-tf-state"
terraform apply -auto-approve

# Expected: ~8-12 minutes for GKE cluster creation
```

### Step 2: Bootstrap ArgoCD

```bash
./scripts/deploy.sh
# Expected: ~5 minutes for ArgoCD to come up
```

### Step 3: List available backups and restore

```bash
# List available Velero backups
velero backup get

# Sample output:
# NAME                          STATUS     STARTED                  COMPLETED
# daily-backup-20240115020000   Completed  2024-01-15 02:00:00 UTC  2024-01-15 02:03:22 UTC

# Restore from the most recent backup
BACKUP_NAME="daily-backup-$(date -d yesterday +%Y%m%d)020000"
velero restore create dr-restore-$(date +%Y%m%d) \
  --from-backup "$BACKUP_NAME" \
  --include-namespaces staging,prod,monitoring \
  --wait
```

### Step 4: Verify restore

```bash
# Check all pods are running
kubectl get pods -n staging
kubectl get pods -n prod
kubectl get pods -n monitoring

# Verify ArgoCD apps re-synced
argocd app list

# Run smoke tests
for svc in user-service product-service order-service; do
  echo "Testing $svc..."
  kubectl port-forward -n staging svc/$svc 8888:$(kubectl get svc $svc -n staging -o jsonpath='{.spec.ports[0].port}') &
  sleep 2
  curl -s http://localhost:8888/health | python3 -m json.tool
  kill %1 2>/dev/null
done
```

### Step 5: Validate SLOs

```bash
# Open Grafana and verify SLO dashboard shows healthy baselines
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
# Navigate to: http://localhost:3000 → Service SLO Dashboard
```

---

## Expected RTO Breakdown

| Step | Estimated Time |
|------|---------------|
| Terraform apply (GKE creation) | 10-12 minutes |
| ArgoCD bootstrap | 5 minutes |
| Velero restore | 3-5 minutes |
| Pod readiness (all services) | 5-8 minutes |
| Validation | 5 minutes |
| **Total** | **~30-35 minutes** |

*Note: Measured RTO in test: 31 minutes. Well within the 4-hour target.*
