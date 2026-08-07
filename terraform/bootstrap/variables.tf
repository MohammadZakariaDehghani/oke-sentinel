variable "tenancy_ocid" {
  description = "OCID of the tenancy. Tag namespaces and the state bucket are tenancy-level concerns."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment that owns the state bucket. Often the tenancy root for a personal tenancy."
  type        = string
}

variable "region" {
  description = "OCI region identifier, for example \"eu-frankfurt-1\"."
  type        = string
}

variable "oci_auth_method" {
  description = "How the provider authenticates: ApiKey, SecurityToken, InstancePrincipal or ResourcePrincipal."
  type        = string
  default     = "ApiKey"

  validation {
    condition     = contains(["ApiKey", "SecurityToken", "InstancePrincipal", "ResourcePrincipal"], var.oci_auth_method)
    error_message = "oci_auth_method must be one of ApiKey, SecurityToken, InstancePrincipal, ResourcePrincipal."
  }
}

variable "oci_config_file_profile" {
  description = "Profile in ~/.oci/config to read when oci_auth_method is ApiKey or SecurityToken. Keeps keys and fingerprints out of this repository."
  type        = string
  default     = "DEFAULT"
}

variable "state_bucket_name" {
  description = "Name of the Object Storage bucket holding Terraform state for every environment."
  type        = string
  default     = "oke-sentinel-tfstate"
}

variable "tag_namespace_name" {
  description = "Name of the defined tag namespace used for cost tracking."
  type        = string
  default     = "sentinel"
}

variable "cost_centers" {
  description = "Allowed values for the CostCenter tag. An empty list means any value is accepted."
  type        = list(string)
  default     = []
}

variable "create_customer_secret_key" {
  description = <<-EOT
    Create a Customer Secret Key for state_backend_user_ocid. This is the
    access key / secret key pair the S3-compatible Object Storage endpoint
    needs. Off by default: the secret half is only returned once and would
    land in this stack's local state. Creating it in the console and putting
    it straight into a password manager is the better habit.
  EOT
  type        = bool
  default     = false
}

variable "state_backend_user_ocid" {
  description = "OCID of the IAM user the Customer Secret Key belongs to. Required when create_customer_secret_key is true."
  type        = string
  default     = null
}

variable "freeform_tags" {
  description = "Freeform tags applied to the bucket."
  type        = map(string)
  default = {
    project    = "oke-sentinel"
    managed_by = "terraform"
    stack      = "bootstrap"
  }
}
