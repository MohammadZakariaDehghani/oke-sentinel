variable "compartment_id" {
  description = "OCID of the compartment that owns the cluster and node pool."
  type        = string
}

variable "tenancy_id" {
  description = "OCID of the tenancy. Used only to list availability domains."
  type        = string
}

variable "name_prefix" {
  description = "Prefix applied to every resource display name, for example \"sentinel-dev\"."
  type        = string
}

variable "kubernetes_version" {
  description = <<-EOT
    Kubernetes version for the control plane and node pool, for example
    "v1.35.2". OKE supports the three most recent minor versions; check what is
    currently offered with
    `oci ce cluster-options get --cluster-option-id all`.
  EOT
  type        = string

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must look like \"v1.35.2\"."
  }
}

variable "cluster_type" {
  description = <<-EOT
    "ENHANCED_CLUSTER" or "BASIC_CLUSTER". Enhanced clusters are required for
    cluster add-ons, workload identity and the higher node limits; workload
    identity is what lets the External Secrets Operator authenticate to OCI
    Vault without a stored key, so this project defaults to enhanced.
  EOT
  type        = string
  default     = "ENHANCED_CLUSTER"

  validation {
    condition     = contains(["ENHANCED_CLUSTER", "BASIC_CLUSTER"], var.cluster_type)
    error_message = "cluster_type must be ENHANCED_CLUSTER or BASIC_CLUSTER."
  }
}

variable "vcn_id" {
  description = "OCID of the VCN the cluster lives in."
  type        = string
}

variable "control_plane_subnet_id" {
  description = "OCID of the subnet holding the Kubernetes API endpoint."
  type        = string
}

variable "control_plane_nsg_id" {
  description = "OCID of the NSG applied to the Kubernetes API endpoint."
  type        = string
}

variable "load_balancer_subnet_id" {
  description = "OCID of the subnet where OKE creates service load balancers."
  type        = string
}

variable "worker_subnet_id" {
  description = "OCID of the private subnet holding worker node VNICs."
  type        = string
}

variable "worker_nsg_id" {
  description = "OCID of the NSG applied to worker nodes."
  type        = string
}

variable "pod_subnet_id" {
  description = "OCID of the private subnet that pod IPs come from."
  type        = string
}

variable "pod_nsg_id" {
  description = "OCID of the NSG applied to pod VNICs."
  type        = string
}

variable "is_api_endpoint_public" {
  description = "Whether the Kubernetes API endpoint gets a public IP."
  type        = bool
  default     = false
}

variable "services_cidr" {
  description = "CIDR for Kubernetes ClusterIP services. Must not overlap the VCN."
  type        = string
  default     = "10.96.0.0/16"
}

# --- Node pool -------------------------------------------------------------

variable "node_pool_size" {
  description = "Number of worker nodes in the pool."
  type        = number
  default     = 3

  validation {
    condition     = var.node_pool_size >= 1
    error_message = "node_pool_size must be at least 1."
  }
}

variable "node_shape" {
  description = <<-EOT
    Compute shape for worker nodes. VM.Standard.A1.Flex is Ampere (arm64) and is
    the shape covered by the Always Free allowance; VM.Standard.E4.Flex and
    E5.Flex are AMD (x86_64). Set node_shape_is_arm to match.
  EOT
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "node_shape_is_arm" {
  description = "Set true when node_shape is an Ampere (aarch64) shape, so the right node image is selected."
  type        = bool
  default     = false
}

variable "node_ocpus" {
  description = "OCPUs per worker node. One OCPU is two vCPUs on x86 shapes."
  type        = number
  default     = 2
}

variable "node_memory_gbs" {
  description = "Memory per worker node in GB. Elasticsearch data nodes need headroom; see the sizing table in the README."
  type        = number
  default     = 32
}

variable "node_boot_volume_gbs" {
  description = "Boot volume size per worker node in GB. Minimum 50."
  type        = number
  default     = 100

  validation {
    condition     = var.node_boot_volume_gbs >= 50
    error_message = "node_boot_volume_gbs must be at least 50."
  }
}

variable "max_pods_per_node" {
  description = <<-EOT
    Maximum pods per node under VCN-native pod networking. Each pod consumes an
    address from the pod subnet, and each node pre-allocates this many. The
    ceiling is 110, and it is also bounded by the VNIC count of the shape.
  EOT
  type        = number
  default     = 31

  validation {
    condition     = var.max_pods_per_node >= 1 && var.max_pods_per_node <= 110
    error_message = "max_pods_per_node must be between 1 and 110."
  }
}

variable "node_image_id" {
  description = "OCID of a specific worker node image. Leave null to select the newest Oracle Linux 8 OKE image matching kubernetes_version and the shape architecture."
  type        = string
  default     = null
}

variable "ssh_public_key" {
  description = "Optional SSH public key installed on worker nodes. Nodes are in private subnets, so this is only usable through a bastion."
  type        = string
  default     = null
}

variable "node_eviction_grace_duration" {
  description = "How long to wait for pods to drain when a node is being removed, as an ISO 8601 duration."
  type        = string
  default     = "PT60M"
}

# --- Audit log export ------------------------------------------------------

variable "enable_audit_log_export" {
  description = <<-EOT
    Create the OCI Streaming stream and Service Connector that forward tenancy
    audit events (which include Kubernetes API server audit events for OKE) to
    a Kafka-compatible endpoint that Filebeat consumes. See the module README
    for why this indirection exists on a managed control plane.
  EOT
  type        = bool
  default     = false
}

variable "audit_stream_partitions" {
  description = "Partition count for the audit stream. One is enough for a demo; scale with audit event volume."
  type        = number
  default     = 1
}

variable "audit_stream_retention_hours" {
  description = "How long the audit stream buffers events, in hours. This is a delivery buffer, not the retention policy — retention is enforced by the Elasticsearch ILM policy."
  type        = number
  default     = 24

  validation {
    condition     = var.audit_stream_retention_hours >= 24 && var.audit_stream_retention_hours <= 168
    error_message = "audit_stream_retention_hours must be between 24 and 168."
  }
}

variable "create_service_connector_policy" {
  description = "Create the IAM policy that lets the Service Connector write to the audit stream. Set false if policies are managed centrally."
  type        = bool
  default     = true
}

# --- Tagging ---------------------------------------------------------------

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
