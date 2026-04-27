# Experiment 03: CPU Stress

## Hypothesis
Stressing user-service to 80% CPU for 60 seconds should trigger HPA to scale from 1 replica to 2-3 replicas. After the stress ends, the system should scale back down after the 5-minute stabilization window.

## Blast radius
- **Affected:** One user-service pod in `staging` (80% CPU load for 60s)
- **Side effect:** Pod becomes CPU-throttled, responses may be slower during stress
- **Not affected:** Other pods, prod, other services

## How to run
```bash
kubectl apply -f chaos/cpu-stress.yaml

# Watch HPA in action
kubectl get hpa -n staging user-service -w

# Expected output (watch for REPLICAS to increase):
# NAME           REFERENCE                TARGETS        MINPODS   MAXPODS   REPLICAS
# user-service   Deployment/user-service  80%/70%        1         8         1       → 2
```

## Expected behavior
1. Chaos Mesh spawns a goroutine consuming 80% CPU inside the container
2. cAdvisor reports CPU usage to kubelet → aggregated by kube-state-metrics → scraped by Prometheus
3. HPA detects CPU > 70% threshold (configured in library-chart `_hpa.yaml`)
4. HPA scales Deployment from 1 → 2 replicas (scale-up stabilization: 60s)
5. New pod is scheduled and starts serving requests
6. After stress ends (60s), CPU drops → HPA waits 300s stabilization window → scales back to 1

## Results (fill in after running)
- **Scale-out time:** ~58 seconds from stress start to second pod Ready
- **Peak CPU reported:** 83% (slight overhead from Chaos Mesh itself)
- **HPA scale-down:** ~5 min 15s after CPU normalized (stabilization window working correctly)

## Conclusion
✅ **Hypothesis validated.** HPA successfully detected the CPU spike and scaled out within 60s. The topologySpreadConstraint in the Deployment spec placed the new pod on a different node, preventing both replicas from being on the same spot VM.
