variable "compartment_id" {
  description = "OCID of the compartment that owns the container repositories."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for repository paths, for example \"sentinel-dev\". Repositories are named <prefix>/<repository>."
  type        = string
}

variable "repositories" {
  description = <<-EOT
    Container repositories to create, keyed by short name. `is_immutable`
    prevents a tag from being overwritten once pushed, which is what stops
    "the same tag, different bytes" incidents; leave it on unless a workflow
    genuinely needs mutable tags.
  EOT
  type = map(object({
    is_public    = optional(bool, false)
    is_immutable = optional(bool, true)
    description  = optional(string, "")
  }))
  default = {}
}

variable "create_pull_dynamic_group" {
  description = <<-EOT
    Create the dynamic group and policy that let this cluster's nodes pull from
    these repositories using instance principals, so no registry password has
    to be stored in a Kubernetes imagePullSecret.
  EOT
  type        = bool
  default     = true
}

variable "tenancy_id" {
  description = "OCID of the tenancy. Dynamic groups are always tenancy-scoped, so they cannot be created in the compartment."
  type        = string
  default     = null
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
