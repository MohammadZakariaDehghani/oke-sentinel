# Managed node pool, spread across every availability domain in the region.

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_id
}

# OKE publishes a node image per Kubernetes version, OS version and
# architecture. Rather than hardcode an image OCID that goes stale on every
# patch release, pick the newest matching one at plan time.
data "oci_containerengine_node_pool_option" "this" {
  node_pool_option_id = oci_containerengine_cluster.this.id
  compartment_id      = var.compartment_id
}

locals {
  availability_domains = [
    for ad in data.oci_identity_availability_domains.this.availability_domains : ad.name
  ]

  # Image names look like:
  #   Oracle-Linux-8.10-2026.01.30-0-OKE-1.35.2-numbers
  #   Oracle-Linux-8.10-aarch64-2026.01.30-0-OKE-1.35.2-numbers
  # so the Kubernetes version has to be matched without its leading "v".
  kubernetes_version_bare = trimprefix(var.kubernetes_version, "v")
  version_pattern         = "OKE-${replace(local.kubernetes_version_bare, ".", "\\.")}"

  candidate_images = [
    for source in data.oci_containerengine_node_pool_option.this.sources : source
    if alltrue([
      can(regex("Oracle-Linux-8", source.source_name)),
      can(regex(local.version_pattern, source.source_name)),
      !can(regex("GPU", source.source_name)),
      can(regex("aarch64", source.source_name)) == var.node_shape_is_arm,
    ])
  ]

  # Image names embed a build date, so a lexical sort of names of the same OS
  # minor version puts the newest build last.
  image_ids_by_name = { for source in local.candidate_images : source.source_name => source.image_id }
  newest_image_name = length(local.image_ids_by_name) > 0 ? reverse(sort(keys(local.image_ids_by_name)))[0] : null

  selected_node_image_id = coalesce(
    var.node_image_id,
    local.newest_image_name != null ? local.image_ids_by_name[local.newest_image_name] : null,
  )
}

# Fail at plan time with a readable message rather than at apply time with a
# null image OCID.
resource "terraform_data" "node_image_guard" {
  lifecycle {
    precondition {
      condition     = local.selected_node_image_id != null
      error_message = "No OKE node image matched kubernetes_version ${var.kubernetes_version} for a ${var.node_shape_is_arm ? "aarch64" : "x86_64"} shape. Set node_image_id explicitly, or check `oci ce node-pool-options get --node-pool-option-id all`."
    }
  }
}

resource "oci_containerengine_node_pool" "this" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_id
  name               = "${var.name_prefix}-np"
  kubernetes_version = var.kubernetes_version
  node_shape         = var.node_shape
  ssh_public_key     = var.ssh_public_key

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gbs
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.selected_node_image_id
    boot_volume_size_in_gbs = var.node_boot_volume_gbs
  }

  node_config_details {
    size    = var.node_pool_size
    nsg_ids = [var.worker_nsg_id]

    dynamic "placement_configs" {
      for_each = local.availability_domains
      content {
        availability_domain = placement_configs.value
        subnet_id           = var.worker_subnet_id
      }
    }

    node_pool_pod_network_option_details {
      cni_type          = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids    = [var.pod_subnet_id]
      pod_nsg_ids       = [var.pod_nsg_id]
      max_pods_per_node = var.max_pods_per_node
    }

    is_pv_encryption_in_transit_enabled = true

    freeform_tags = var.freeform_tags
    defined_tags  = var.defined_tags
  }

  # Give Elasticsearch time to relocate shards before a node disappears during
  # an upgrade or scale-down. Without this the default grace period can evict
  # a data pod faster than its replicas can catch up.
  node_eviction_node_pool_settings {
    eviction_grace_duration              = var.node_eviction_grace_duration
    is_force_delete_after_grace_duration = false
  }

  initial_node_labels {
    key   = "oke.sentinel/node-pool"
    value = "${var.name_prefix}-np"
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  depends_on = [terraform_data.node_image_guard]
}
