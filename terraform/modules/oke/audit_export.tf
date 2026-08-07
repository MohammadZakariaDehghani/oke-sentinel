# Getting Kubernetes audit events off a managed control plane.
#
# On a self-managed cluster you set --audit-log-path on the API server and tail
# the file. OKE runs the control plane for you, so there is no file and no
# flag to set: audit events are delivered to the OCI Audit service instead.
#
# The path from there to Elasticsearch is:
#
#   OCI Audit  ->  Service Connector Hub  ->  OCI Streaming  ->  Filebeat
#                                             (Kafka protocol)    kafka input
#
# "_Audit" is a well-known log group identifier that means "this compartment's
# audit log" — it is not an OCID and is not something this module creates.
#
# The kind and local paths do not use any of this. There the API server is
# ours, so security/audit-policy.yaml is mounted and Filebeat tails the file
# directly. Both paths produce the same document shape, which is what the
# detection rules match on; see docs/detections.md.

resource "oci_streaming_stream_pool" "audit" {
  count = var.enable_audit_log_export ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-audit-pool"

  kafka_settings {
    auto_create_topics_enable = false
    log_retention_hours       = var.audit_stream_retention_hours
    num_partitions            = var.audit_stream_partitions
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_streaming_stream" "audit" {
  count = var.enable_audit_log_export ? 1 : 0

  name           = "${var.name_prefix}-k8s-audit"
  stream_pool_id = oci_streaming_stream_pool.audit[0].id
  partitions     = var.audit_stream_partitions

  # This is a delivery buffer, not a retention policy. How long audit data is
  # actually kept is decided by the Elasticsearch ILM policy in
  # kubernetes/base/ilm/.
  retention_in_hours = var.audit_stream_retention_hours

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# The Service Connector runs as a service principal, so it needs to be granted
# access to the stream explicitly. The condition is scoped to service
# connectors in this compartment rather than to one connector OCID, so the
# policy can be created before the connector and does not need updating when
# the connector is replaced.
resource "oci_identity_policy" "service_connector_stream_push" {
  count = var.enable_audit_log_export && var.create_service_connector_policy ? 1 : 0

  compartment_id = var.compartment_id
  name           = "${var.name_prefix}-sch-stream-push"
  description    = "Allow Service Connector Hub to publish audit events to the ${var.name_prefix} audit stream."

  statements = [
    join(" ", [
      "allow any-user to use stream-push in compartment id ${var.compartment_id}",
      "where all {",
      "request.principal.type = 'serviceconnector',",
      "request.principal.compartment.id = '${var.compartment_id}'",
      "}",
    ])
  ]

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_sch_service_connector" "audit_to_stream" {
  count = var.enable_audit_log_export ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-audit-to-stream"
  description    = "Forwards compartment audit events, including Kubernetes API server audit events, to the audit stream for ingestion into Elasticsearch."

  source {
    kind = "logging"

    log_sources {
      compartment_id = var.compartment_id
      log_group_id   = "_Audit"
    }
  }

  target {
    kind      = "streaming"
    stream_id = oci_streaming_stream.audit[0].id
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  depends_on = [oci_identity_policy.service_connector_stream_push]
}
