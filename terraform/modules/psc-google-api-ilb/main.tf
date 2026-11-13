# ==============================================================================
# Module: psc-google-api-ilb
# Main Implementation
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. OPTIONAL PROXY-ONLY SUBNET
# ------------------------------------------------------------------------------

resource "google_compute_subnetwork" "proxy_only_subnet" {
  count         = var.create_proxy_subnet ? 1 : 0
  name          = "${var.name_prefix}-proxy-subnet"
  project       = var.project_id
  region        = var.region
  network       = var.network_id
  ip_cidr_range = var.proxy_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

locals {
  proxy_subnet_id = var.create_proxy_subnet ? google_compute_subnetwork.proxy_only_subnet[0].id : var.proxy_only_subnet_id
}

# ------------------------------------------------------------------------------
# 2. PRIVATE SERVICE CONNECT NETWORK ENDPOINT GROUP (PSC NEG)
# ------------------------------------------------------------------------------

resource "google_compute_region_network_endpoint_group" "psc_neg" {
  name                  = "${var.name_prefix}-psc-neg"
  project               = var.project_id
  region                = var.region
  network               = var.network_id
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = var.psc_target_service

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# 3. REGIONAL CLOUD ARMOR SECURITY POLICY
# ------------------------------------------------------------------------------

resource "google_compute_region_security_policy" "armor_policy" {
  count       = var.enable_cloud_armor && var.custom_security_policy_id == null ? 1 : 0
  name        = "${var.name_prefix}-security-policy"
  project     = var.project_id
  region      = var.region
  description = "Cloud Armor security policy for ${var.name_prefix} PSC backend"
  type        = "CLOUD_ARMOR"

  advanced_options_config {
    json_parsing = "STANDARD"
    log_level    = "VERBOSE"
  }
}

resource "google_compute_region_security_policy_rule" "allow_client_subnets" {
  count           = var.enable_cloud_armor && var.custom_security_policy_id == null ? 1 : 0
  project         = var.project_id
  region          = var.region
  security_policy = google_compute_region_security_policy.armor_policy[0].name
  priority        = 1000
  action          = "allow"
  description     = "Allow authorized internal client subnets"

  match {
    versioned_expr = "SRC_IPS_V1"
    config {
      src_ip_ranges = var.allowed_client_ip_ranges
    }
  }
}

locals {
  security_policy_id = var.enable_cloud_armor ? (
    var.custom_security_policy_id != null ? var.custom_security_policy_id : google_compute_region_security_policy.armor_policy[0].id
  ) : null
}

# ------------------------------------------------------------------------------
# 4. REGIONAL BACKEND SERVICE (PSC NEG + NO HEALTH CHECK)
# ------------------------------------------------------------------------------

resource "google_compute_region_backend_service" "psc_backend" {
  name                  = "${var.name_prefix}-backend-service"
  project               = var.project_id
  region                = var.region
  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = local.security_policy_id

  backend {
    group = google_compute_region_network_endpoint_group.psc_neg.id
  }

  dynamic "log_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      enable      = true
      sample_rate = var.log_sample_rate
    }
  }
}

# ------------------------------------------------------------------------------
# 5. SSL CERTIFICATE & SSL POLICY
# ------------------------------------------------------------------------------

# Automatic self-signed certificate generation if no custom/existing cert is supplied
resource "tls_private_key" "self_signed" {
  count     = var.existing_ssl_certificate_id == null && var.ssl_certificate_pem == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  count           = var.existing_ssl_certificate_id == null && var.ssl_certificate_pem == null ? 1 : 0
  private_key_pem = tls_private_key.self_signed[0].private_key_pem

  subject {
    common_name  = var.custom_domain
    organization = "Internal Enterprise Services"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [var.custom_domain]
}

resource "google_compute_region_ssl_certificate" "ssl_cert" {
  count       = var.existing_ssl_certificate_id == null ? 1 : 0
  name_prefix = "${var.name_prefix}-cert-"
  project     = var.project_id
  region      = var.region
  description = "SSL Certificate for ${var.name_prefix} Load Balancer"
  certificate = var.ssl_certificate_pem != null ? var.ssl_certificate_pem : tls_self_signed_cert.self_signed[0].cert_pem
  private_key = var.ssl_private_key_pem != null ? var.ssl_private_key_pem : tls_private_key.self_signed[0].private_key_pem

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  ssl_certificate_id = var.existing_ssl_certificate_id != null ? var.existing_ssl_certificate_id : google_compute_region_ssl_certificate.ssl_cert[0].id
}

resource "google_compute_region_ssl_policy" "ssl_policy" {
  name            = "${var.name_prefix}-ssl-policy"
  project         = var.project_id
  region          = var.region
  profile         = var.ssl_policy_profile
  min_tls_version = var.ssl_policy_min_tls_version
}

# ------------------------------------------------------------------------------
# 6. URL MAP WITH HOST HEADER REWRITE
# ------------------------------------------------------------------------------

resource "google_compute_region_url_map" "url_map" {
  name            = "${var.name_prefix}-url-map"
  project         = var.project_id
  region          = var.region
  default_service = google_compute_region_backend_service.psc_backend.id

  host_rule {
    hosts        = [var.custom_domain]
    path_matcher = "api-routes"
  }

  path_matcher {
    name            = "api-routes"
    default_service = google_compute_region_backend_service.psc_backend.id

    route_rules {
      priority = 1

      match_rules {
        prefix_match = "/"
      }

      service = google_compute_region_backend_service.psc_backend.id

      route_action {
        url_rewrite {
          host_rewrite = var.psc_target_service
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# 7. TARGET HTTPS PROXY & FORWARDING RULE
# ------------------------------------------------------------------------------

resource "google_compute_region_target_https_proxy" "https_proxy" {
  name             = "${var.name_prefix}-target-proxy"
  project          = var.project_id
  region           = var.region
  url_map          = google_compute_region_url_map.url_map.id
  ssl_certificates = [local.ssl_certificate_id]
  ssl_policy       = google_compute_region_ssl_policy.ssl_policy.id
}

resource "google_compute_address" "ilb_ip" {
  name         = "${var.name_prefix}-ilb-ip"
  project      = var.project_id
  region       = var.region
  subnetwork   = var.subnetwork_id
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

resource "google_compute_forwarding_rule" "forwarding_rule" {
  name                  = "${var.name_prefix}-forwarding-rule"
  project               = var.project_id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.https_proxy.id
  network               = var.network_id
  subnetwork            = var.subnetwork_id
  ip_address            = google_compute_address.ilb_ip.address

  depends_on = [google_compute_subnetwork.proxy_only_subnet]
}

# ------------------------------------------------------------------------------
# 8. CLOUD DNS PRIVATE ZONE & RECORD SET
# ------------------------------------------------------------------------------

resource "google_dns_managed_zone" "private_zone" {
  count       = var.create_dns_record && var.create_dns_zone ? 1 : 0
  name        = var.dns_zone_name
  project     = var.project_id
  dns_name    = "${var.dns_domain}."
  description = "Private DNS zone for ${var.name_prefix}"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.network_id
    }
  }
}

locals {
  resolved_dns_zone_name = var.create_dns_zone ? google_dns_managed_zone.private_zone[0].name : var.dns_zone_name
}

resource "google_dns_record_set" "custom_domain_a_record" {
  count        = var.create_dns_record && local.resolved_dns_zone_name != null ? 1 : 0
  name         = "${var.custom_domain}."
  project      = var.project_id
  managed_zone = local.resolved_dns_zone_name
  type         = "A"
  ttl          = var.dns_record_ttl
  rrdatas      = [google_compute_forwarding_rule.forwarding_rule.ip_address]
}
