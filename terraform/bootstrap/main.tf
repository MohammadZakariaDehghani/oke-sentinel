# One-time setup that every environment stack depends on:
#   * the Object Storage bucket that holds Terraform state
#   * the defined tag namespace used for cost tracking
#
# Run this once, by hand, before running dev or prod.

provider "oci" {
  auth                = var.oci_auth_method
  config_file_profile = var.oci_config_file_profile
  region              = var.region
  tenancy_ocid        = var.tenancy_ocid
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "tfstate" {
  #checkov:skip=CKV_OCI_9:A customer-managed key would have to live in the vault created by the stacks whose state this bucket holds, which is circular. Oracle-managed encryption is the deliberate choice for the bootstrap bucket only.
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = var.state_bucket_name

  access_type = "NoPublicAccess"

  # State files contain generated passwords and every resource identifier in
  # the tenancy. Versioning turns a bad apply or a corrupted upload into
  # something recoverable instead of terminal.
  versioning = "Enabled"

  # Oracle-managed encryption. Point kms_key_id at a customer-managed key if
  # your policy requires one — note that would create a dependency on the
  # vault module, which itself stores state in this bucket.
  storage_tier = "Standard"

  # Emit events on object create, update and delete. Terraform state changing
  # is exactly the kind of thing worth being able to alarm on, and the events
  # are free until something subscribes to them.
  object_events_enabled = true

  freeform_tags = var.freeform_tags
}

# Defined tags are the ones that show up in OCI cost analysis as filterable
# dimensions. Freeform tags do not, which is why both exist: freeform for
# anything useful to a human reading the console, defined for anything
# finance needs to slice a bill by.
resource "oci_identity_tag_namespace" "this" {
  compartment_id = var.tenancy_ocid
  name           = var.tag_namespace_name
  description    = "Cost tracking and ownership tags for the oke-sentinel project."
  is_retired     = false
}

resource "oci_identity_tag" "cost_center" {
  tag_namespace_id = oci_identity_tag_namespace.this.id
  name             = "CostCenter"
  description      = "Cost centre the resource is billed to."
  is_cost_tracking = true
  is_retired       = false

  dynamic "validator" {
    for_each = length(var.cost_centers) > 0 ? [1] : []
    content {
      validator_type = "ENUM"
      values         = var.cost_centers
    }
  }
}

resource "oci_identity_tag" "environment" {
  tag_namespace_id = oci_identity_tag_namespace.this.id
  name             = "Environment"
  description      = "Lifecycle environment the resource belongs to."
  is_cost_tracking = true
  is_retired       = false

  validator {
    validator_type = "ENUM"
    values         = ["dev", "prod"]
  }
}

resource "oci_identity_tag" "owner" {
  tag_namespace_id = oci_identity_tag_namespace.this.id
  name             = "Owner"
  description      = "Team or person accountable for the resource."
  is_cost_tracking = true
  is_retired       = false
}

# The access key / secret key pair for the S3-compatible endpoint. See the
# variable description for why this is off by default.
resource "oci_identity_customer_secret_key" "state_backend" {
  count = var.create_customer_secret_key ? 1 : 0

  user_id      = var.state_backend_user_ocid
  display_name = "${var.state_bucket_name}-backend"

  lifecycle {
    precondition {
      condition     = var.state_backend_user_ocid != null
      error_message = "create_customer_secret_key requires state_backend_user_ocid."
    }
  }
}
