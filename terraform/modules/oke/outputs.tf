output "cluster_id" {
  description = "OCID of the OKE cluster."
  value       = oci_containerengine_cluster.this.id
}

output "cluster_name" {
  description = "Display name of the OKE cluster."
  value       = oci_containerengine_cluster.this.name
}

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster."
  value       = oci_containerengine_cluster.this.kubernetes_version
}

output "cluster_endpoints" {
  description = "Cluster API endpoints. The private endpoint is always present; the public one only when is_api_endpoint_public is true."
  value       = oci_containerengine_cluster.this.endpoints
}

output "node_pool_id" {
  description = "OCID of the managed node pool."
  value       = oci_containerengine_node_pool.this.id
}

output "node_image_id" {
  description = "OCID of the image the node pool was created from."
  value       = local.selected_node_image_id
}

output "availability_domains" {
  description = "Availability domains the node pool is spread across."
  value       = local.availability_domains
}

output "audit_stream_id" {
  description = "OCID of the audit event stream, or null when audit log export is disabled."
  value       = var.enable_audit_log_export ? oci_streaming_stream.audit[0].id : null
}

output "audit_stream_endpoint" {
  description = "Kafka-compatible bootstrap endpoint for the audit stream pool, for Filebeat's kafka input. Null when audit log export is disabled."
  value       = var.enable_audit_log_export ? oci_streaming_stream_pool.audit[0].endpoint_fqdn : null
}

output "kubeconfig_command" {
  description = "The oci CLI command that writes a kubeconfig for this cluster."
  value = join(" ", [
    "oci ce cluster create-kubeconfig",
    "--cluster-id ${oci_containerengine_cluster.this.id}",
    "--file $HOME/.kube/config",
    "--token-version 2.0.0",
    "--kube-endpoint ${var.is_api_endpoint_public ? "PUBLIC_ENDPOINT" : "PRIVATE_ENDPOINT"}",
  ])
}
