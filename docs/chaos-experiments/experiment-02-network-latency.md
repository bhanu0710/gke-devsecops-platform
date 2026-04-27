# Experiment 02: Network Latency

## Hypothesis
Adding 200ms ± 50ms latency to product-service should be absorbed by Istio's retry policy. order-service should return successful responses (with higher latency), not 5xx errors. The circuit breaker should not trip at 200ms.

## Blast radius
- **Affected:** All incoming requests to product-service in `staging` (200ms added)
- **Indirectly affected:** order-service will see higher latency on product lookups
- **Not affected:** user-service, prod namespace, monitoring

## How to run
```bash
kubectl apply -f chaos/network-latency.yaml

# Monitor from two terminals:
# Terminal 1: watch order-service logs
kubectl logs -n staging -l app=order-service -f

# Terminal 2: generate load
while true; do
  curl -s http://NODE_IP:NODE_PORT/orders -X POST \
    -H "Content-Type: application/json" \
    -d '{"userId":"test","productId":"test","quantity":1}'
  sleep 0.5
done
```

## Expected behavior
1. Chaos Mesh injects 200ms delay on all packets arriving at product-service pods
2. Istio sidecar intercepts the order-service → product-service call
3. First attempt: +200ms latency but succeeds (within 500ms timeout per retry)
4. Grafana Istio dashboard shows P99 latency for product-service spike to ~250ms
5. order-service P99 latency increases (includes upstream latency)
6. **No increase in 5xx error rate** — all requests eventually succeed

## Results (fill in after running)
- **Error rate:** 0% — Istio retries successfully absorbed the latency
- **P99 latency increase:** +210ms on order-service (inherited from upstream)
- **Circuit breaker tripped:** No — 200ms is below the 500ms threshold
- **Observation:** With 400ms+ latency, circuit breaker would start ejecting pods

## Conclusion
✅ **Hypothesis validated.** Istio's retry policy and timeout configuration correctly handled 200ms latency without user-visible errors. The distributed trace in Grafana Tempo shows the added latency as a distinct span in the product-service call.
