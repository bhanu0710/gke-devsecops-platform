# modules/vpc/main.tf
# Creates an isolated VPC for the GKE cluster with secondary IP ranges required
# for GKE alias IPs (pods and services get IPs from these ranges, not the node subnet).
# Cloud NAT is critical: nodes use private IPs, but need outbound internet for image pulls.

resource "google_compute_network" "main" {
  name                    = "${var.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false # Custom subnet mode — we control every CIDR
  description             = "VPC for GKE DevSecOps platform"
}

resource "google_compute_subnetwork" "main" {
  name                     = "${var.name_prefix}-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.main.self_link
  ip_cidr_range            = var.subnet_cidr      # Nodes get IPs from here
  private_ip_google_access = true                  # Allows private nodes to reach Google APIs

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr # GKE alias IP range for pods
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr # GKE alias IP range for services (ClusterIPs)
  }
}

# Cloud Router is the prerequisite for Cloud NAT
resource "google_compute_router" "main" {
  name    = "${var.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.self_link
}

# Cloud NAT lets private nodes pull container images and reach external APIs
# without requiring public IP addresses on each node (saves cost + attack surface)
resource "google_compute_router_nat" "main" {
  name                               = "${var.name_prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY" # Log NAT errors — useful for diagnosing pull failures
  }
}

# Allow all internal (intra-VPC) traffic — pods need to talk to each other
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name_prefix}-allow-internal"
  project = var.project_id
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]
  description   = "Allow all intra-cluster traffic"
}

# Deny all external ingress except HTTPS — GKE API server uses 443
# NodePort services are exposed via 30000-32767 for direct access without LB
resource "google_compute_firewall" "allow_https" {
  name    = "${var.name_prefix}-allow-https-nodeport"
  project = var.project_id
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["443", "30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Allow HTTPS and NodePort range from internet"
}

# GKE master needs to reach nodes for health checks, exec, logs
resource "google_compute_firewall" "allow_master_webhooks" {
  name    = "${var.name_prefix}-allow-master-webhooks"
  project = var.project_id
  network = google_compute_network.main.self_link

  allow {
    protocol = "tcp"
    ports    = ["8443", "9443", "15017"] # webhook, OPA, Istio pilot webhook
  }

  source_ranges = [var.master_ipv4_cidr_block]
  description   = "Allow GKE control plane to reach admission webhooks on nodes"
}
