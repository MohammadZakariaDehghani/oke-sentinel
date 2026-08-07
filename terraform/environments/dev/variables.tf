variable "tenancy_ocid" {
  description = "OCID of the tenancy."
  type        = string
}

variable "parent_compartment_ocid" {
  description = "OCID of the compartment this environment's compartment is created under. Often the tenancy root."
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
  description = "Profile in ~/.oci/config to read when oci_auth_method is ApiKey or SecurityToken."
  type        = string
  default     = "DEFAULT"
}

variable "name_prefix" {
  description = "Prefix for every resource name in this environment."
  type        = string
  default     = "sentinel-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster, for example \"v1.35.2\". Check what OKE currently offers with `oci ce cluster-options get --cluster-option-id all`."
  type        = string
}

variable "tag_namespace" {
  description = "Defined tag namespace created by the bootstrap stack."
  type        = string
  default     = "sentinel"
}

variable "cost_center" {
  description = "Value for the CostCenter defined tag."
  type        = string
  default     = "platform"
}

variable "owner" {
  description = "Value for the Owner defined tag."
  type        = string
}

variable "api_endpoint_allowed_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API. Your own egress address, not 0.0.0.0/0."
  type        = list(string)
  default     = []
}

variable "load_balancer_allowed_cidrs" {
  description = "CIDRs allowed to reach public load balancers on 443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_pool_size" {
  description = "Number of worker nodes."
  type        = number
  default     = 2
}

variable "node_shape" {
  description = "Compute shape for worker nodes."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "node_shape_is_arm" {
  description = "True when node_shape is an Ampere (aarch64) shape."
  type        = bool
  default     = false
}

variable "node_ocpus" {
  description = "OCPUs per worker node."
  type        = number
  default     = 2
}

variable "node_memory_gbs" {
  description = "Memory per worker node in GB."
  type        = number
  default     = 24
}

variable "ssh_public_key" {
  description = "Optional SSH public key for worker nodes. Nodes are private, so this needs a bastion to be useful."
  type        = string
  default     = null
}
