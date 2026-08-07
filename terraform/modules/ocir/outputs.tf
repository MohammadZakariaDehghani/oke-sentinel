output "repository_ids" {
  description = "Map of short repository name to repository OCID."
  value       = { for name, repo in oci_artifacts_container_repository.this : name => repo.id }
}

output "repository_paths" {
  description = "Map of short repository name to the repository path within the registry, without the region prefix or tenancy namespace."
  value       = { for name, repo in oci_artifacts_container_repository.this : name => repo.display_name }
}

output "dynamic_group_name" {
  description = "Name of the dynamic group granted pull access, or null when it was not created."
  value       = var.create_pull_dynamic_group ? oci_identity_dynamic_group.node_pull[0].name : null
}
