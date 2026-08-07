# OCI Vault: the one place a credential is allowed to exist.
#
# Secret values are generated here rather than passed in. A value passed in as
# a Terraform variable has to live somewhere first — a tfvars file, a CI
# variable, a shell history — and each of those is a copy that outlives its
# usefulness. Generating means the only copies are the vault and the state
# file.

resource "oci_kms_vault" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-vault"
  vault_type     = var.vault_type

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_kms_key" "secrets" {
  compartment_id      = var.compartment_id
  display_name        = "${var.name_prefix}-secrets-key"
  management_endpoint = oci_kms_vault.this.management_endpoint
  protection_mode     = var.key_protection_mode

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "random_password" "this" {
  for_each = var.generated_secrets

  length  = each.value.length
  special = each.value.special

  # Elasticsearch and Kibana pass credentials through URLs, config files and
  # shell invocations in various places. Excluding the characters that need
  # escaping in those contexts avoids a class of "works locally, fails in the
  # container" problem without meaningfully reducing entropy at this length.
  override_special = "-_=+."
}

resource "oci_vault_secret" "this" {
  for_each = var.generated_secrets

  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.this.id
  key_id         = oci_kms_key.secrets.id
  secret_name    = each.key
  description    = each.value.description != "" ? each.value.description : "Generated secret ${each.key} for ${var.name_prefix}."

  secret_content {
    content_type = "BASE64"
    content      = base64encode(random_password.this[each.key].result)
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
