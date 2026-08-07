output "object_storage_namespace" {
  description = "Object Storage namespace for this tenancy. Part of the S3-compatible endpoint hostname."
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "state_bucket_name" {
  description = "Name of the state bucket."
  value       = oci_objectstorage_bucket.tfstate.name
}

output "s3_compatible_endpoint" {
  description = "The endpoint to put in each environment's backend configuration."
  value       = "https://${data.oci_objectstorage_namespace.this.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}

output "tag_namespace" {
  description = "Name of the defined tag namespace. Defined tag keys are \"<namespace>.<tag>\"."
  value       = oci_identity_tag_namespace.this.name
}

output "customer_secret_key_id" {
  description = "OCID of the Customer Secret Key, when one was created. The secret half is not output; read it from state or the console once and store it in a password manager."
  value       = var.create_customer_secret_key ? oci_identity_customer_secret_key.state_backend[0].id : null
}
