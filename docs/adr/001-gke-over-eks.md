# ADR-001: Use GKE instead of AWS EKS

**Status:** Accepted  
**Date:** 2024-01-15  
**Author:** Bhanu Pratap Singh

---

## Context

This project is a portfolio piece demonstrating DevSecOps competency to potential employers. It must be:

1. Built entirely within a $300 GCP free trial credit
2. Demonstrable without ongoing monthly costs after the trial
3. Production-realistic (not a toy cluster)

**AWS EKS** costs $0.10/hour ($72/month) for the control plane with **zero free tier credit**. Even a single-node cluster would cost ~$100/month before any workloads.

**GKE Standard** offers a `$74.40/month` credit that covers one zonal cluster's control plane completely, effectively making the control plane free indefinitely — not just during a trial period.

---

## Decision

Use a **GKE Standard zonal cluster** in `us-central1-a`.

Key configuration choices driven by this decision:
- **Zonal** (not regional) — one control plane replica = covered by the full $74.40 credit. A regional cluster splits the credit across 3 control plane replicas, reducing cost savings.
- **NodePort ingress** — avoids the GCP HTTP(S) Load Balancer ($18.26/month). All UIs accessed via `kubectl port-forward` or NodePort.
- **Spot VMs** — e2-medium spot is ~70% cheaper than on-demand. Acceptable for a stateless demo workload.
- **Scale-to-zero** — `min_node_count = 0` lets the node pool scale to zero when idle (via `destroy.sh`), incurring $0 compute cost between sessions.

---

## Consequences

### Positive
- **$0 control plane cost** — GKE credit covers this permanently
- **GKE-native features** — Workload Identity, Binary Authorization, Dataplane V2 (eBPF NetworkPolicy), Google Managed Prometheus all work out-of-the-box with no extra setup
- **Multi-cloud signal** — demonstrates awareness of both major cloud providers (EKS experience documented in prior projects)
- **Total spend < $220** for a complete build including all security and observability tools

### Negative
- **NodePort only** — requires `kubectl port-forward` to access UIs; less realistic than a managed ingress for external traffic demos
- **Zonal HA** — a zone failure would take the cluster down. Acceptable for a portfolio project; explicitly called out in the architecture documentation
- **Spot VM evictions** — nodes can be preempted. Handled by Spot node tolerations and PodDisruptionBudgets ensuring minimum 1 replica stays running during eviction

### Neutral
- All skills demonstrated (Terraform, GitOps, Istio, OPA, Chaos Engineering) are cloud-agnostic and directly applicable to EKS, AKS, or any CNCF-compliant Kubernetes distribution
