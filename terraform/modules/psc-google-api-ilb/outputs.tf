# ==============================================================================
# Module: psc-google-api-ilb
# Outputs Definition
# ==============================================================================

output "forwarding_rule_ip" {
  description = "The internal IP address reserved for the Application Load Balancer."
  value       = google_compute_forwarding_rule.forwarding_rule.ip_address
}

output "forwarding_rule_id" {
  description = "The resource ID of the internal forwarding rule."
  value       = google_compute_forwarding_rule.forwarding_rule.id
}

output "custom_domain_url" {
  description = "The custom HTTPS endpoint for clients to connect to the Google API."
  value       = "https://${var.custom_domain}"
}

output "custom_domain" {
  description = "The custom domain name configured on the load balancer."
  value       = var.custom_domain
}

output "psc_target_service" {
  description = "The target Google API service for the PSC NEG."
  value       = var.psc_target_service
}

output "psc_neg_id" {
  description = "The resource ID of the PSC Network Endpoint Group."
  value       = google_compute_region_network_endpoint_group.psc_neg.id
}

output "backend_service_id" {
  description = "The resource ID of the regional backend service."
  value       = google_compute_region_backend_service.psc_backend.id
}

output "security_policy_id" {
  description = "The resource ID of the Cloud Armor security policy."
  value       = local.security_policy_id
}

output "url_map_id" {
  description = "The resource ID of the regional URL Map."
  value       = google_compute_region_url_map.url_map.id
}

output "proxy_subnet_id" {
  description = "The resource ID of the proxy-only subnet utilized by the load balancer."
  value       = local.proxy_subnet_id
}

output "dns_record_name" {
  description = "The fully qualified DNS record name created."
  value       = var.create_dns_record ? google_dns_record_set.custom_domain_a_record[0].name : null
}

output "curl_test_command" {
  description = "Command to test connectivity to the custom Google API endpoint."
  value       = "curl -vk https://${var.custom_domain}"
}
