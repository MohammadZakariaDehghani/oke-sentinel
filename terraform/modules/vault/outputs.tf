output "vault_id" {
  description = "OCID of the vault."
  value       = oci_kms_vault.this.id
}

output "vault_management_endpoint" {
  description = "Management endpoint of the vault, needed when creating keys against it."
  value       = oci_kms_vault.this.management_endpoint
}

output "key_id" {
  description = "OCID of the master encryption key protecting the secrets."
  value       = oci_kms_key.secrets.id
}

output "secret_ids" {
  description = "Map of secret name to secret OCID. Values are not exposed; the External Secrets Operator reads them from the vault at runtime."
  value       = { for name, secret in oci_vault_secret.this : name => secret.id }
}

output "dynamic_group_name" {
  description = "Name of the dynamic group granted read access to secret bundles, or null when workload identity access was not created."
  value       = var.create_workload_identity_access ? oci_identity_dynamic_group.secret_reader[0].name : null
}
