# OKE workload identity: how a pod reads a secret without holding a credential.
#
# The alternative is an OCI API signing key mounted into the External Secrets
# Operator, which is a private key sitting in a Kubernetes Secret whose only
# job is to fetch other secrets. Workload identity replaces it with a token the
# cluster mints for one service account, which OCI IAM then evaluates against
# the matching rule below.
#
# Workload identity requires an enhanced cluster. The oke module defaults to
# ENHANCED_CLUSTER for this reason.

resource "oci_identity_dynamic_group" "secret_reader" {
  count = var.create_workload_identity_access ? 1 : 0

  compartment_id = var.tenancy_id
  name           = "${var.name_prefix}-secret-readers"
  description    = "The ${var.workload_service_account} service account in the ${var.workload_namespace} namespace of the ${var.name_prefix} cluster."

  # This matches one service account in one namespace in one compartment. It is
  # deliberately not a match on the whole cluster: every workload that matches
  # gets the policy below, so the rule is the blast radius.
  matching_rule = join("", [
    "ALL {",
    "resource.type = 'workload', ",
    "resource.compartment.id = '${var.compartment_id}', ",
    "resource.namespace = '${var.workload_namespace}', ",
    "resource.serviceaccount.name = '${var.workload_service_account}'",
    "}",
  ])

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  lifecycle {
    precondition {
      condition     = var.tenancy_id != null
      error_message = "create_workload_identity_access requires tenancy_id: dynamic groups are tenancy-scoped."
    }
  }
}

resource "oci_identity_policy" "secret_reader" {
  count = var.create_workload_identity_access ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-secret-read"
  description    = "Allow the ${var.name_prefix} External Secrets Operator to read secret contents from the ${var.name_prefix} vault."

  # read secret-bundles is the permission that returns the secret *value*.
  # read secret-family would also allow listing and reading metadata; this is
  # the narrower of the two.
  statements = [
    "allow dynamic-group ${oci_identity_dynamic_group.secret_reader[0].name} to read secret-bundles in compartment id ${var.compartment_id}",
    "allow dynamic-group ${oci_identity_dynamic_group.secret_reader[0].name} to read vaults in compartment id ${var.compartment_id}",
  ]

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
