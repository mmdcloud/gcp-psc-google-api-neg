# Terraform Module: `psc-google-api-ilb`

Production-grade, reusable Terraform module to deploy a **Private Service Connect Network Endpoint Group (PSC NEG)** backend fronted by a **Regional Internal Application Load Balancer** for Google APIs in Google Cloud Platform.

---

## Architecture

```
[VPC Client] ---> [Private Cloud DNS (custom_domain)]
                       |
                       v
     [Internal Forwarding Rule VIP : 443]
                       |
     [Envoy Proxy Instances (Proxy-Only Subnet)]
                       |
          [Target HTTPS Proxy + SSL Policy]
                       |
     [URL Map (Host Rewrite -> psc_target_service)]
                       |
         [Cloud Armor Regional Security Policy]
                       |
          [Regional Backend Service (HTTPS)]
                       |
     [PSC Regional NEG (PRIVATE_SERVICE_CONNECT)]
                       |
              (Google Backbone)
                       |
                       v
            [Target Google Cloud API]
        (Cloud Storage, Cloud KMS, etc.)
```

---

## Features

- **Any Supported Google API**: Easily targets Multi-regional APIs (`storage.googleapis.com`), Regional APIs (`cloudkms.<region>.rep.googleapis.com`), or Global APIs.
- **Custom Domains & SSL Termination**: Terminate TLS at the load balancer using enterprise custom domains (`storage.internal.example.com`).
- **Host Header Rewriting**: Automatically injects a URL Map rewrite rule so Google API endpoints receive their expected `Host` header.
- **Google Cloud Armor**: Enforces IP allowlisting and body inspection before requests reach Google APIs.
- **Observability**: Built-in HTTP request access logging with configurable sample rate.
- **Flexible Networking**: Uses existing proxy-only subnets or provisions one on demand.
- **Automated DNS**: Provisions Private Cloud DNS zones and A records.

---

## Usage Examples

### Example 1: Multi-Regional API (Google Cloud Storage)

```hcl
module "storage_psc_backend" {
  source = "./modules/psc-google-api-ilb"

  name_prefix          = "psc-storage"
  project_id           = var.project_id
  region               = "us-central1"
  network_id           = module.vpc.vpc_id
  subnetwork_id        = module.vpc.subnet_ids["workload-subnet"]
  proxy_only_subnet_id = module.vpc.subnet_ids["proxy-subnet"]

  psc_target_service   = "storage.googleapis.com"
  custom_domain        = "storage.internal.example.com"
  create_dns_record    = true
  dns_zone_name        = "internal-corp-zone"

  allowed_client_ip_ranges = ["10.0.0.0/8"]
}
```

### Example 2: Regional API (Cloud KMS)

```hcl
module "kms_psc_backend" {
  source = "./modules/psc-google-api-ilb"

  name_prefix          = "psc-kms"
  project_id           = var.project_id
  region               = "us-central1"
  network_id           = module.vpc.vpc_id
  subnetwork_id        = module.vpc.subnet_ids["workload-subnet"]
  proxy_only_subnet_id = module.vpc.subnet_ids["proxy-subnet"]

  psc_target_service   = "cloudkms.us-central1.rep.googleapis.com"
  custom_domain        = "kms.internal.example.com"
  create_dns_record    = true
  dns_zone_name        = "internal-corp-zone"

  allowed_client_ip_ranges = ["10.0.1.0/24"]
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `region` | GCP region for regional resources | `string` | - | yes |
| `network_id` | VPC Network ID / self_link | `string` | - | yes |
| `subnetwork_id` | Workload subnet ID for ILB IP allocation | `string` | - | yes |
| `psc_target_service` | Target Google API endpoint (e.g. `storage.googleapis.com`) | `string` | - | yes |
| `custom_domain` | Custom FQDN for client requests | `string` | - | yes |
| `name_prefix` | Resource naming prefix | `string` | `"psc-api"` | no |
| `proxy_only_subnet_id` | Existing proxy-only subnet ID | `string` | `null` | no |
| `create_proxy_subnet` | Whether to create a proxy-only subnet | `bool` | `false` | no |
| `proxy_subnet_cidr` | CIDR for proxy-only subnet (if created) | `string` | `null` | no |
| `enable_cloud_armor` | Attach Cloud Armor policy to backend | `bool` | `true` | no |
| `allowed_client_ip_ranges` | Client CIDRs permitted by Cloud Armor | `list(string)` | `["10.0.0.0/8", ...]` | no |
| `create_dns_record` | Create Cloud DNS A record for custom domain | `bool` | `true` | no |
| `dns_zone_name` | Name of Cloud DNS private zone | `string` | `null` | no |
| `create_dns_zone` | Create a new private DNS zone | `bool` | `false` | no |
| `dns_domain` | Base domain if creating a new zone | `string` | `null` | no |
| `enable_logging` | Enable HTTP access logging on backend | `bool` | `true` | no |
| `log_sample_rate` | Request log sample rate (0.0 to 1.0) | `number` | `1.0` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `forwarding_rule_ip` | Internal IP address reserved for the Application Load Balancer |
| `custom_domain_url` | Full HTTPS URL (`https://<custom_domain>`) |
| `psc_neg_id` | Resource ID of the PSC Network Endpoint Group |
| `backend_service_id` | Resource ID of the regional backend service |
| `security_policy_id` | Resource ID of the Cloud Armor security policy |
| `proxy_subnet_id` | Resource ID of the proxy-only subnet used |
| `curl_test_command` | Example test command to verify connectivity |
