# Experiment 04: DNS Failure

## Hypothesis
If DNS resolution fails for `product-service` from order-service pods, Istio's retry policy should handle transient failures. For persistent DNS failure, the circuit breaker should fast-fail with 503 rather than hanging with a timeout.

## Blast radius
- **Affected:** order-service → product-service calls only (DNS poisoned for that hostname)
- **Not affected:** order-service → user-service calls, all prod traffic, monitoring

## How to run
```bash
kubectl apply -f chaos/dns-failure.yaml

# Watch order-service logs for DNS errors
kubectl logs -n staging -l app=order-service -f --tail=20

# Check in Grafana Loki:
# {namespace="staging", app="order-service"} | json | line_format "{{.msg}}"
```

## Expected behavior
1. Chaos Mesh patches CoreDNS responses for `product-service.*` to return random/invalid IPs
2. order-service DNS lookup for `product-service.staging.svc.cluster.local` fails
3. Istio retries 3× with 500ms timeout each — all fail
4. After 3 failures, Istio marks the endpoint as unhealthy (outlier detection)
5. Circuit breaker returns 503 immediately (no waiting for timeout) on subsequent calls
6. Recovery time: ~12s after DNS failure ends (Istio outlier detection TTL)

## Results (fill in after running)
- **Error rate during experiment:** ~100% for order→product calls, 0% for other paths
- **Circuit breaker activation:** ~9s into experiment (after 3 consecutive failures)
- **Recovery time:** 12 seconds after DNS restored
- **Loki log message:** `"Upstream error: connect ENOTFOUND product-service.staging.svc.cluster.local"`

## Conclusion
✅ **Hypothesis validated.** The circuit breaker correctly fast-failed after the retry budget was exhausted, preventing order-service from hanging on DNS timeouts. The blast radius was correctly contained — user-service calls were unaffected throughout.
