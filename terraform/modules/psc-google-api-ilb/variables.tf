# ==============================================================================
# Module: psc-google-api-ilb
# Variables Definition
# ==============================================================================

variable "project_id" {
  description = "The Google Cloud Project ID."
  type        = string
  default     = null
}

variable "region" {
  description = "The GCP region where the PSC NEG and regional Load Balancer are deployed."
  type        = string
}

variable "name_prefix" {
  description = "Prefix applied to all created resource names for identification and namespace isolation."
  type        = string
  default     = "psc-api"
}

variable "network_id" {
  description = "The ID or self_link of the VPC network."
  type        = string
}

variable "subnetwork_id" {
  description = "The ID or self_link of the subnetwork where the Load Balancer internal IP address will be allocated."
  type        = string
}

variable "proxy_only_subnet_id" {
  description = "The ID or self_link of an existing proxy-only subnet. Required if create_proxy_subnet is false."
  type        = string
  default     = null
}

variable "create_proxy_subnet" {
  description = "Whether to create a new proxy-only subnet within this module. If false, proxy_only_subnet_id must be provided."
  type        = bool
  default     = false
}

variable "proxy_subnet_cidr" {
  description = "CIDR block for the proxy-only subnet if create_proxy_subnet is true. Must be at least /26."
  type        = string
  default     = null
}

variable "psc_target_service" {
  description = "The target Google API service endpoint. For Regional Backend Services, this must be a regional endpoint in the same region, formatted as '<service>.<region>.rep.googleapis.com' (e.g. 'storage.us-central1.rep.googleapis.com' or 'cloudkms.us-central1.rep.googleapis.com')."
  type        = string
}

variable "custom_domain" {
  description = "The custom FQDN for client requests (e.g., 'storage.internal.example.com')."
  type        = string
}

variable "create_dns_record" {
  description = "Whether to create a Cloud DNS A record mapping custom_domain to the Load Balancer IP."
  type        = bool
  default     = true
}

variable "create_dns_zone" {
  description = "Whether to create a new private Cloud DNS managed zone. If false, an existing zone named dns_zone_name must exist."
  type        = bool
  default     = false
}

variable "dns_zone_name" {
  description = "Name of the Cloud DNS private managed zone."
  type        = string
  default     = null
}

variable "dns_domain" {
  description = "The base DNS domain name if create_dns_zone is true (e.g. 'internal.example.com')."
  type        = string
  default     = null
}

variable "dns_record_ttl" {
  description = "TTL in seconds for the DNS A record."
  type        = number
  default     = 300
}

variable "enable_cloud_armor" {
  description = "Whether to attach a Cloud Armor security policy to the regional backend service."
  type        = bool
  default     = true
}

variable "custom_security_policy_id" {
  description = "ID or self_link of an existing regional Cloud Armor security policy. If null and enable_cloud_armor is true, a security policy will be created by this module."
  type        = string
  default     = null
}

variable "allowed_client_ip_ranges" {
  description = "List of internal CIDR ranges permitted by Cloud Armor to access the backend service."
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "existing_ssl_certificate_id" {
  description = "ID of an existing regional SSL certificate to attach to the target HTTPS proxy. If provided, ssl_certificate_pem and auto-generation are bypassed."
  type        = string
  default     = null
}

variable "ssl_certificate_pem" {
  description = "Custom SSL Certificate in PEM format. If null and existing_ssl_certificate_id is null, a self-signed certificate is auto-generated."
  type        = string
  default     = null
}

variable "ssl_private_key_pem" {
  description = "Custom SSL Private Key in PEM format corresponding to ssl_certificate_pem."
  type        = string
  default     = null
  sensitive   = true
}

variable "ssl_policy_profile" {
  description = "Profile for the regional SSL policy. Options: 'COMPATIBLE', 'MODERN', 'RESTRICTED', or 'CUSTOM'."
  type        = string
  default     = "RESTRICTED"
}

variable "ssl_policy_min_tls_version" {
  description = "Minimum TLS version allowed by the SSL policy. Options: 'TLS_1_0', 'TLS_1_1', 'TLS_1_2'."
  type        = string
  default     = "TLS_1_2"
}

variable "enable_logging" {
  description = "Whether to enable access logging on the regional backend service."
  type        = bool
  default     = true
}

variable "log_sample_rate" {
  description = "Sample rate for request access logging (0.0 to 1.0). 1.0 logs 100% of requests."
  type        = number
  default     = 1.0

  validation {
    condition     = var.log_sample_rate >= 0.0 && var.log_sample_rate <= 1.0
    error_message = "log_sample_rate must be between 0.0 and 1.0."
  }
}
