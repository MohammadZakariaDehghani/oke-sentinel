# Development environment.
#
# Smaller than prod in every dimension that costs money: two nodes instead of
# three, less memory, a public API endpoint for laptop access, and no audit log
# export. What it does not compromise on is the shape of the thing — same
# modules, same NSG model, same tagging — so a change proven here means
# something in prod.

provider "oci" {
  auth                = var.oci_auth_method
  config_file_profile = var.oci_config_file_profile
  region              = var.region
  tenancy_ocid        = var.tenancy_ocid
}

locals {
  environment = "dev"

  # Freeform tags: for a human reading the console.
  freeform_tags = {
    project     = "oke-sentinel"
    environment = local.environment
    managed_by  = "terraform"
    stack       = "environments/${local.environment}"
    repository  = "github.com/MohammadZakariaDehghani/oke-sentinel"
  }

  # Defined tags: for cost analysis, which cannot filter on freeform tags.
  # The namespace and these tag keys are created by the bootstrap stack.
  defined_tags = {
    "${var.tag_namespace}.Environment" = local.environment
    "${var.tag_namespace}.CostCenter"  = var.cost_center
    "${var.tag_namespace}.Owner"       = var.owner
  }
}

resource "oci_identity_compartment" "this" {
  compartment_id = var.parent_compartment_ocid
  name           = var.name_prefix
  description    = "OKE Sentinel ${local.environment} environment."

  # Dev is meant to be torn down. Prod sets this to false so that a stray
  # `terraform destroy` cannot take the compartment with it.
  enable_delete = true

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}

module "network" {
  source = "../../modules/network"

  compartment_id = oci_identity_compartment.this.id
  name_prefix    = var.name_prefix

  vcn_cidr      = "10.10.0.0/16"
  vcn_dns_label = "sentineldev"

  subnet_cidr_load_balancer = "10.10.0.0/24"
  subnet_cidr_control_plane = "10.10.1.0/28"
  subnet_cidr_workers       = "10.10.2.0/24"
  subnet_cidr_pods          = "10.10.64.0/18"

  # Public endpoint in dev so a laptop can reach the API without a bastion.
  # Still restricted to api_endpoint_allowed_cidrs by the NSG.
  is_api_endpoint_public      = true
  api_endpoint_allowed_cidrs  = var.api_endpoint_allowed_cidrs
  load_balancer_allowed_cidrs = var.load_balancer_allowed_cidrs

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}

module "oke" {
  source = "../../modules/oke"

  compartment_id     = oci_identity_compartment.this.id
  tenancy_id         = var.tenancy_ocid
  name_prefix        = var.name_prefix
  kubernetes_version = var.kubernetes_version

  vcn_id                  = module.network.vcn_id
  control_plane_subnet_id = module.network.control_plane_subnet_id
  control_plane_nsg_id    = module.network.control_plane_nsg_id
  load_balancer_subnet_id = module.network.load_balancer_subnet_id
  worker_subnet_id        = module.network.worker_subnet_id
  worker_nsg_id           = module.network.worker_nsg_id
  pod_subnet_id           = module.network.pod_subnet_id
  pod_nsg_id              = module.network.pod_nsg_id

  is_api_endpoint_public = true

  node_pool_size    = var.node_pool_size
  node_shape        = var.node_shape
  node_shape_is_arm = var.node_shape_is_arm
  node_ocpus        = var.node_ocpus
  node_memory_gbs   = var.node_memory_gbs
  ssh_public_key    = var.ssh_public_key

  # Dev reads audit events from the OCI console rather than paying for a
  # stream. The kind-based integration path is where the audit pipeline is
  # actually exercised.
  enable_audit_log_export = false

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}

module "ocir" {
  source = "../../modules/ocir"

  compartment_id = oci_identity_compartment.this.id
  tenancy_id     = var.tenancy_ocid
  name_prefix    = var.name_prefix

  repositories = {
    "sample-api" = {
      description = "Sample workload emitting structured JSON logs and Prometheus metrics."
    }
    "oci-inventory" = {
      description = "Governance CLI that inventories OCI resources and indexes findings into Elasticsearch."
    }
  }

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}

module "vault" {
  source = "../../modules/vault"

  compartment_id = oci_identity_compartment.this.id
  tenancy_id     = var.tenancy_ocid
  name_prefix    = var.name_prefix

  generated_secrets = {
    "elastic-superuser-password" = {
      length      = 32
      description = "Password for the Elasticsearch elastic user, read by the External Secrets Operator."
    }
    "kibana-encryption-key" = {
      length      = 32
      special     = false
      description = "Kibana saved-object encryption key. Rotating it invalidates encrypted saved objects."
    }
  }

  workload_namespace       = "external-secrets"
  workload_service_account = "external-secrets"

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}
