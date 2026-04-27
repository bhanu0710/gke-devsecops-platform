# modules/gke/main.tf
# GKE Standard cluster — zonal (us-central1-a) so the control plane is covered
# by GKE's $74.40/month free tier credit. Regional clusters cost the same credit
# for 3 control plane replicas instead of 1, which is wasteful for a portfolio project.

resource "google_container_cluster" "main" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.zone # Zonal = single control plane = free tier applies

  # Remove the default node pool immediately after cluster creation.
  # We manage node pools as separate resources for cleaner lifecycle management.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = var.subnet_name

  # GKE Dataplane V2 uses eBPF for NetworkPolicy enforcement.
  # This replaces Calico (which would need its own node resources to run).
  datapath_provider = "ADVANCED_DATAPATH"

  # Alias IPs allow pods to have routable IPs without NAT between nodes.
  # Required for GKE Dataplane V2 and Istio ambient mesh.
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # REGULAR channel auto-upgrades to stable minor versions.
  # RAPID is too aggressive for a stable demo; STABLE lags too far behind security patches.
  release_channel {
    channel = "REGULAR"
  }

  # Workload Identity lets pods authenticate to GCP APIs using a bound K8s ServiceAccount
  # instead of mounting a static JSON key. This is the zero-credential approach.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Shielded nodes verify node identity and integrity at boot using TPM attestation.
  # Prevents compromised node images from joining the cluster silently.
  enable_shielded_nodes = true

  # Binary Authorization ensures only signed, attested images can be deployed.
  # The policy itself is managed separately in the binary-authorization module.
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Logging and monitoring to Google Cloud Operations (formerly Stackdriver)
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true # Google Managed Prometheus — free for GKE workloads up to certain limits
    }
  }

  # Network policy is enforced by Dataplane V2; this flag acknowledges it to the API
  network_policy {
    enabled  = false # Dataplane V2 handles this natively
    provider = "PROVIDER_UNSPECIFIED"
  }

  # Private cluster: nodes have no public IPs (saves cost, reduces attack surface).
  # The control plane is still accessible via private endpoint.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.private_endpoint # false for staging, true for prod
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Allow the local machine (for kubectl access from laptop) + CI system
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Maintenance window: run upgrades at 3am UTC Sunday to minimise disruption
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-07T03:00:00Z"
      end_time   = "2024-01-07T07:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  addons_config {
    # HTTP load balancing disabled — we use NodePort to avoid the $18/mo LB charge
    http_load_balancing {
      disabled = true
    }
    # HPA is essential for the chaos CPU-stress experiment (scale-out demo)
    horizontal_pod_autoscaling {
      disabled = false
    }
    # GKE DNS used for service discovery; required for Istio ambient mesh
    dns_cache_config {
      enabled = true
    }
  }
}

# Separate node pool — makes it easy to add/replace pools without recreating the cluster
resource "google_container_node_pool" "main" {
  name       = "main-pool"
  project    = var.project_id
  cluster    = google_container_cluster.main.name
  location   = var.zone
  node_count = null # Let autoscaler manage count

  # Spot VMs are ~60-91% cheaper than on-demand e2-medium.
  # Acceptable for a portfolio project; not suitable for stateful prod workloads.
  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard" # Standard persistent disk, cheaper than SSD

    spot = true # Spot VMs — GKE will evict when capacity is needed elsewhere

    # Use Workload Identity at the node pool level (service account with minimal permissions)
    service_account = var.node_service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Shielded instance config to match cluster-level shielded node policy
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Workload Identity metadata for pods on this node
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Taint spot nodes so only tolerating workloads land here.
    # System-critical pods that don't tolerate this won't be scheduled on spot.
    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    labels = {
      env        = var.environment
      node-type  = "spot"
      managed-by = "terraform"
    }

    metadata = {
      disable-legacy-endpoints = "true" # Security: disable metadata v1 endpoints
    }
  }

  autoscaling {
    min_node_count  = var.min_node_count # 0 allows scale-to-zero (destroy.sh sets this)
    max_node_count  = var.max_node_count
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true  # Auto-repair unhealthy nodes
    auto_upgrade = true  # Keep nodes on the same version as control plane
  }

  upgrade_settings {
    max_surge       = 1 # Create 1 extra node during upgrades to maintain capacity
    max_unavailable = 0 # Never take a node offline without a replacement ready
  }
}
