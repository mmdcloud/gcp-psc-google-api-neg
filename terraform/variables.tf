variable "project_id" {
  type        = string
  description = "The Google Cloud Project ID."
  default     = "encoded-alpha-457108-e8"
}

variable "region" {
  type        = string
  description = "The GCP region for regional resources and the Internal Application Load Balancer."
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The GCP zone for zonal client resources."
  default     = "us-central1-a"
}

variable "name_prefix" {
  type        = string
  description = "Naming prefix for resources."
  default     = "psc-api"
}

variable "network_name" {
  type        = string
  description = "Name of the VPC network."
  default     = "psc-neg-vpc"
}

variable "workload_subnet_cidr" {
  type        = string
  description = "CIDR block for the client workload subnet."
  default     = "10.0.1.0/24"
}

variable "proxy_subnet_cidr" {
  type        = string
  description = "CIDR block for the proxy-only subnet required by Envoy-based Internal Application Load Balancers. Must be at least /26."
  default     = "10.0.128.0/24"
}

variable "psc_target_service" {
  type        = string
  description = "The target Google API service for the PSC NEG. Examples: 'storage.googleapis.com' (multi-regional Cloud Storage), 'cloudkms.us-central1.rep.googleapis.com' (regional Cloud KMS)."
  default     = "storage.googleapis.com"
}

variable "dns_zone_name" {
  type        = string
  description = "Name of the Cloud DNS private managed zone."
  default     = "internal-example-zone"
}

variable "dns_domain" {
  type        = string
  description = "The DNS domain name for the private zone (without trailing dot)."
  default     = "internal.example.com"
}

variable "custom_domain" {
  type        = string
  description = "The fully qualified custom domain name for clients accessing the Google API through the load balancer (e.g. storage.internal.example.com)."
  default     = "storage.internal.example.com"
}

variable "cloud_armor_allowed_ip_ranges" {
  type        = list(string)
  description = "List of client CIDR ranges permitted by Cloud Armor to access the backend service."
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "ssl_certificate" {
  type        = string
  description = "Custom SSL Certificate in PEM format. If left null, a self-signed certificate will be automatically generated."
  default     = null
}

variable "ssl_private_key" {
  type        = string
  description = "Custom SSL Private Key in PEM format corresponding to ssl_certificate. If left null, an auto-generated private key will be used."
  default     = null
  sensitive   = true
}

variable "enable_client_vm" {
  type        = bool
  description = "Whether to provision a private test VM instance in the workload subnet to test PSC NEG connectivity."
  default     = true
}
