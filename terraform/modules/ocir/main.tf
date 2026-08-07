# Container repositories in the OCI Registry.
#
# Repositories are created up front rather than on first push. Creating them
# here means the immutability and visibility settings are code-reviewed
# properties rather than whatever the first `docker push` happened to imply.

resource "oci_artifacts_container_repository" "this" {
  for_each = var.repositories

  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}/${each.key}"
  is_public      = each.value.is_public
  is_immutable   = each.value.is_immutable

  dynamic "readme" {
    for_each = each.value.description != "" ? [each.value.description] : []
    content {
      content = readme.value
      format  = "text/plain"
    }
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Let worker nodes pull images as instance principals. The alternative is an
# imagePullSecret holding an auth token, which then has to be rotated and
# cannot be scoped to one cluster.
resource "oci_identity_dynamic_group" "node_pull" {
  count = var.create_pull_dynamic_group ? 1 : 0

  compartment_id = var.tenancy_id
  name           = "${var.name_prefix}-oke-nodes"
  description    = "Worker node instances belonging to the ${var.name_prefix} OKE cluster."
  # Worker nodes are the only compute in this compartment, so compartment
  # membership is a sufficient and stable match. If you later run other
  # instances here, narrow this to the node pool's defined tag instead.
  matching_rule = "ALL {instance.compartment.id = '${var.compartment_id}'}"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  lifecycle {
    precondition {
      condition     = var.tenancy_id != null
      error_message = "create_pull_dynamic_group requires tenancy_id: dynamic groups are tenancy-scoped."
    }
  }
}

resource "oci_identity_policy" "node_pull" {
  count = var.create_pull_dynamic_group ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-ocir-pull"
  description    = "Allow ${var.name_prefix} worker nodes to pull images from the repositories in this compartment."

  statements = [
    "allow dynamic-group ${oci_identity_dynamic_group.node_pull[0].name} to read repos in compartment id ${var.compartment_id}",
  ]

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
