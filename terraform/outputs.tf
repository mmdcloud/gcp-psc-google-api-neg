output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the consumer VPC network."
}

output "workload_subnet_id" {
  value       = module.vpc.subnet_ids["${var.network_name}-workload-subnet"]
  description = "The ID of the workload subnet."
}

output "proxy_subnet_id" {
  value       = module.vpc.subnet_ids["${var.network_name}-proxy-subnet"]
  description = "The ID of the regional proxy-only subnet."
}

output "load_balancer_ip" {
  value       = module.psc_google_api_ilb.forwarding_rule_ip
  description = "The internal IP address reserved for the Application Load Balancer."
}

output "custom_domain_url" {
  value       = module.psc_google_api_ilb.custom_domain_url
  description = "The custom HTTPS endpoint for clients to connect to the Google API."
}

output "psc_target_service" {
  value       = module.psc_google_api_ilb.psc_target_service
  description = "The Google API target endpoint configured on the PSC NEG."
}

output "psc_neg_id" {
  value       = module.psc_google_api_ilb.psc_neg_id
  description = "The resource ID of the PSC Network Endpoint Group."
}

output "backend_service_id" {
  value       = module.psc_google_api_ilb.backend_service_id
  description = "The resource ID of the regional backend service."
}

output "cloud_armor_policy_id" {
  value       = module.psc_google_api_ilb.security_policy_id
  description = "The resource ID of the Cloud Armor security policy."
}

output "test_client_ssh_command" {
  value       = var.enable_client_vm ? "gcloud compute ssh ${var.name_prefix}-test-client --zone=${var.zone} --tunnel-through-iap" : null
  description = "Command to SSH into the test VM through Identity-Aware Proxy."
}

output "curl_verification_command" {
  value       = module.psc_google_api_ilb.curl_test_command
  description = "Example curl command to run inside a VPC client to verify PSC NEG backend connectivity."
}
