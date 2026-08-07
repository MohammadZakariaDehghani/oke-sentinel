# Production environment.
#
# The differences from dev are deliberate and few: the API endpoint is private,
# there are three nodes so losing one does not lose Elasticsearch quorum, the
# compartment cannot be deleted by a stray destroy, and the audit log export is
# on. Everything else is the same modules with the same arguments, which is the
# point — a change proven in dev means something here.

provider "oci" {
  auth                = var.oci_auth_method
  config_file_profile = var.oci_config_file_profile
  region              = var.region
  tenancy_ocid        = var.tenancy_ocid
}

locals {
  environment = "prod"

  freeform_tags = {
    project     = "oke-sentinel"
    environment = local.environment
    managed_by  = "terraform"
    stack       = "environments/${local.environment}"
    repository  = "github.com/MohammadZakariaDehghani/oke-sentinel"
  }

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

  # A compartment that cannot be deleted by Terraform. Removing this stack
  # should not be able to take the compartment, and everything anyone forgot
  # was in it, along with it.
  enable_delete = false

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}

module "network" {
  source = "../../modules/network"

  compartment_id = oci_identity_compartment.this.id
  name_prefix    = var.name_prefix

  vcn_cidr      = "10.20.0.0/16"
  vcn_dns_label = "sentinelprod"

  subnet_cidr_load_balancer = "10.20.0.0/24"
  subnet_cidr_control_plane = "10.20.1.0/28"
  subnet_cidr_workers       = "10.20.2.0/24"
  subnet_cidr_pods          = "10.20.64.0/18"

  # No public API endpoint. Operators reach it from inside the VCN.
  is_api_endpoint_public      = false
  api_endpoint_allowed_cidrs  = var.bastion_cidrs
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

  is_api_endpoint_public = false

  node_pool_size    = var.node_pool_size
  node_shape        = var.node_shape
  node_shape_is_arm = var.node_shape_is_arm
  node_ocpus        = var.node_ocpus
  node_memory_gbs   = var.node_memory_gbs
  ssh_public_key    = var.ssh_public_key

  # Ninety minutes to drain. Elasticsearch relocating shards off a node that
  # is about to disappear is slower than anything else in the cluster, and
  # rushing it is how you turn a rolling upgrade into a red index.
  node_eviction_grace_duration = "PT90M"

  enable_audit_log_export      = true
  audit_stream_partitions      = 2
  audit_stream_retention_hours = 48

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
      is_immutable = true
      description  = "Sample workload emitting structured JSON logs and Prometheus metrics."
    }
    "oci-inventory" = {
      is_immutable = true
      description  = "Governance CLI that inventories OCI resources and indexes findings into Elasticsearch."
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
      length      = 48
      description = "Password for the Elasticsearch elastic user, read by the External Secrets Operator."
    }
    "kibana-encryption-key" = {
      length      = 48
      special     = false
      description = "Kibana saved-object encryption key. Rotating it invalidates encrypted saved objects."
    }
  }

  workload_namespace       = "external-secrets"
  workload_service_account = "external-secrets"

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}
