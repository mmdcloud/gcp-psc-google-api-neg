# ==============================================================================
# Production-Grade Architecture:
# Private Service Connect Google API Backend via Reusable Modules
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. VPC NETWORKING (Using Reusable VPC Module)
# ------------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  vpc_name                = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  subnets = [
    {
      name                     = "${var.network_name}-workload-subnet"
      ip_cidr_range            = var.workload_subnet_cidr
      region                   = var.region
      description              = "Subnet for workloads and PSC Load Balancer internal VIP"
      private_ip_google_access = true
    },
    {
      name          = "${var.network_name}-proxy-subnet"
      ip_cidr_range = var.proxy_subnet_cidr
      region        = var.region
      description   = "Regional proxy-only subnet for Envoy-based Internal Application Load Balancers"
      purpose       = "REGIONAL_MANAGED_PROXY"
      role          = "ACTIVE"
    }
  ]

  firewall_data = [
    {
      name          = "${var.network_name}-allow-client-to-ilb"
      description   = "Allow internal clients to access the Load Balancer on port 443"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = var.cloud_armor_allowed_ip_ranges
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["443"]
        }
      ]
    },
    {
      name          = "${var.network_name}-allow-proxy-to-backends"
      description   = "Allow Envoy proxies in proxy-only subnet to communicate with backends"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = [var.proxy_subnet_cidr]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["443", "80"]
        }
      ]
    },
    {
      name          = "${var.network_name}-allow-iap-ssh"
      description   = "Allow SSH via Google Cloud Identity-Aware Proxy (IAP)"
      direction     = "INGRESS"
      priority      = 1000
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["psc-client"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]
}

# ------------------------------------------------------------------------------
# 2. PSC GOOGLE API LOAD BALANCER (Using Reusable PSC Module)
# ------------------------------------------------------------------------------

module "psc_google_api_ilb" {
  source = "./modules/psc-google-api-ilb"

  project_id           = var.project_id
  region               = var.region
  name_prefix          = var.name_prefix
  network_id           = module.vpc.vpc_id
  subnetwork_id        = module.vpc.subnet_ids["${var.network_name}-workload-subnet"]
  proxy_only_subnet_id = module.vpc.subnet_ids["${var.network_name}-proxy-subnet"]

  # Google API Target (e.g. storage.googleapis.com, cloudkms.us-central1.rep.googleapis.com)
  psc_target_service = var.psc_target_service
  custom_domain      = var.custom_domain

  # DNS Configuration
  create_dns_record = true
  create_dns_zone   = true
  dns_zone_name     = var.dns_zone_name
  dns_domain        = var.dns_domain

  # Security and Observability
  enable_cloud_armor       = true
  allowed_client_ip_ranges = var.cloud_armor_allowed_ip_ranges
  enable_logging           = true
  log_sample_rate          = 1.0

  # SSL Configuration (Defaults to automated self-signed if null)
  ssl_certificate_pem = var.ssl_certificate
  ssl_private_key_pem = var.ssl_private_key
}

# ------------------------------------------------------------------------------
# 3. OPTIONAL VERIFICATION CLIENT VM
# ------------------------------------------------------------------------------

resource "google_compute_instance" "client_vm" {
  count        = var.enable_client_vm ? 1 : 0
  name         = "${var.name_prefix}-test-client"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["psc-client"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network    = module.vpc.vpc_id
    subnetwork = module.vpc.subnet_ids["${var.network_name}-workload-subnet"]
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update && apt-get install -y curl dnsutils jq
  EOT
}
