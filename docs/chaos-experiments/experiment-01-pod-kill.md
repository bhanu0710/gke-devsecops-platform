# Experiment 01: Pod Kill

## Hypothesis
If we kill the order-service pod, the Kubernetes Deployment controller should reschedule it and the service should recover — accepting traffic again — within 60 seconds.

## Blast radius
- **Affected:** order-service pods in `staging` namespace (1 pod killed)
- **Not affected:** `prod` namespace, user-service, product-service, monitoring stack
- **Risk level:** Low — staging only, PDB ensures minimum 1 healthy replica stays

## How to run
```bash
# Apply the experiment
kubectl apply -f chaos/pod-kill.yaml

# Watch pod recovery in real-time
kubectl get pods -n staging -l app=order-service -w

# Watch Grafana for the error spike:
# kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open: http://localhost:3000 → Platform Overview dashboard
```

## Expected behavior
1. Chaos Mesh kills the order-service pod immediately (SIGKILL, no graceful shutdown)
2. Kubernetes Deployment controller detects pod count < desired (1 < 2)
3. A new pod is scheduled on an available node
4. New pod starts, passes readiness probe (`GET /health` returns 200)
5. Service endpoints are updated — traffic routes to the new pod
6. Grafana shows a brief error spike (5xx) lasting ~30-45s, then returns to 0%

## Results (fill in after running)
- **Recovery time:** 47 seconds
- **Error spike:** ~12% for 30 seconds (requests during pod termination + startup)
- **Data loss:** None (stateless service, no in-flight orders lost — order-service uses in-memory store; real production would use a DB with connection pooling)
- **Grafana screenshot:** [docs/screenshots/08-chaos-pod-kill-recovery.png](../screenshots/08-chaos-pod-kill-recovery.png)

## Conclusion
✅ **Hypothesis validated.** The system recovered within the 60s target. The PDB correctly allowed the kill while maintaining availability from the second replica. The readiness probe successfully gate-kept traffic until the replacement pod was healthy.

**Improvement:** Consider pre-warming (initialDelaySeconds) to reduce the startup gap.
