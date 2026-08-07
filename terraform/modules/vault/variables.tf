variable "compartment_id" {
  description = "OCID of the compartment that owns the vault, key and secrets."
  type        = string
}

variable "tenancy_id" {
  description = "OCID of the tenancy. Dynamic groups are tenancy-scoped."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix applied to every resource display name, for example \"sentinel-dev\"."
  type        = string
}

variable "vault_type" {
  description = <<-EOT
    "DEFAULT" for a virtual private vault or "VIRTUAL_PRIVATE" for dedicated
    partitions. VIRTUAL_PRIVATE has a per-hour charge and is not needed for a
    demo; DEFAULT is the shared-infrastructure option.
  EOT
  type        = string
  default     = "DEFAULT"

  validation {
    condition     = contains(["DEFAULT", "VIRTUAL_PRIVATE"], var.vault_type)
    error_message = "vault_type must be DEFAULT or VIRTUAL_PRIVATE."
  }
}

variable "key_protection_mode" {
  description = <<-EOT
    "SOFTWARE" or "HSM". HSM-protected keys are billed per key version;
    SOFTWARE keys are not, and are sufficient for encrypting demo secrets.
  EOT
  type        = string
  default     = "SOFTWARE"

  validation {
    condition     = contains(["SOFTWARE", "HSM"], var.key_protection_mode)
    error_message = "key_protection_mode must be SOFTWARE or HSM."
  }
}

variable "generated_secrets" {
  description = <<-EOT
    Secrets whose values Terraform generates and stores in the vault, keyed by
    secret name. Nothing here takes a value from configuration, because a value
    passed in as a variable ends up in a tfvars file, a CI variable, or a shell
    history. The generated value is readable only through the vault (and, as
    with any generated resource, through Terraform state — see the README).
  EOT
  type = map(object({
    length      = optional(number, 32)
    special     = optional(bool, true)
    description = optional(string, "")
  }))
  default = {}

  validation {
    condition     = alltrue([for s in var.generated_secrets : s.length >= 16])
    error_message = "Generated secrets must be at least 16 characters."
  }
}

variable "create_workload_identity_access" {
  description = <<-EOT
    Create the dynamic group and policy that let a specific Kubernetes service
    account read these secrets through OKE workload identity. This is what the
    External Secrets Operator authenticates with; without it, something has to
    hold an API key.
  EOT
  type        = bool
  default     = true
}

variable "workload_namespace" {
  description = "Kubernetes namespace of the service account allowed to read secrets."
  type        = string
  default     = "external-secrets"
}

variable "workload_service_account" {
  description = "Name of the Kubernetes service account allowed to read secrets."
  type        = string
  default     = "external-secrets"
}

variable "freeform_tags" {
  description = "Freeform tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags applied to every resource, keyed as \"Namespace.Key\"."
  type        = map(string)
  default     = {}
}
