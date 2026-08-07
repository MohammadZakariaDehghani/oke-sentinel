output "compartment_id" {
  description = "OCID of the compartment holding this environment."
  value       = oci_identity_compartment.this.id
}

output "cluster_id" {
  description = "OCID of the OKE cluster."
  value       = module.oke.cluster_id
}

output "kubeconfig_command" {
  description = "Command that writes a kubeconfig for this cluster. Run it from somewhere inside the VCN — the endpoint is private."
  value       = module.oke.kubeconfig_command
}

output "vault_id" {
  description = "OCID of the vault holding the Elasticsearch credentials."
  value       = module.vault.vault_id
}

output "secret_ids" {
  description = "Map of secret name to OCID, for the External Secrets Operator configuration."
  value       = module.vault.secret_ids
}

output "load_balancer_nsg_id" {
  description = "NSG to annotate LoadBalancer Services with, via oci.oraclecloud.com/oci-network-security-groups."
  value       = module.network.load_balancer_nsg_id
}

output "audit_stream_endpoint" {
  description = "Kafka-compatible bootstrap endpoint carrying audit events, for Filebeat's kafka input."
  value       = module.oke.audit_stream_endpoint
}

output "audit_stream_id" {
  description = "OCID of the audit event stream."
  value       = module.oke.audit_stream_id
}

output "ocir_repository_paths" {
  description = "Repository paths within the registry, for tagging images before push."
  value       = module.ocir.repository_paths
}
