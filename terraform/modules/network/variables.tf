variable "compartment_id" {
  description = "OCID of the compartment that owns the VCN and every network resource in it."
  type        = string
}

variable "name_prefix" {
  description = "Prefix applied to every resource display name, for example \"sentinel-dev\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be lowercase alphanumeric with hyphens, 3-30 characters, starting with a letter."
  }
}

variable "vcn_cidr" {
  description = "IPv4 CIDR block for the VCN. Must contain every subnet CIDR below."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN. Alphanumeric, max 15 characters, no hyphens."
  type        = string
  default     = "sentinel"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,14}$", var.vcn_dns_label))
    error_message = "vcn_dns_label must be lowercase alphanumeric, start with a letter, and be at most 15 characters."
  }
}

variable "subnet_cidr_load_balancer" {
  description = "CIDR for the public subnet that holds service load balancers."
  type        = string
  default     = "10.0.0.0/24"
}

variable "subnet_cidr_control_plane" {
  description = "CIDR for the subnet holding the OKE Kubernetes API endpoint. A /28 is sufficient."
  type        = string
  default     = "10.0.1.0/28"
}

variable "subnet_cidr_workers" {
  description = "CIDR for the private subnet holding worker node VNICs."
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_cidr_pods" {
  description = <<-EOT
    CIDR for the private subnet that holds pod IPs under VCN-native pod networking.
    Every pod takes an address from this subnet, so size it for
    (max nodes x max pods per node) with headroom. The /18 default gives 16,382
    usable addresses.
  EOT
  type        = string
  default     = "10.0.64.0/18"
}

variable "is_api_endpoint_public" {
  description = <<-EOT
    Whether the Kubernetes API endpoint gets a public IP. Public is convenient
    for a laptop-driven demo; private plus a bastion or VPN is the production
    posture. Either way the endpoint is protected by an NSG.
  EOT
  type        = bool
  default     = false
}

variable "api_endpoint_allowed_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach the Kubernetes API on TCP 6443. Keep this to your own
    egress addresses. Defaults to empty, which means only in-VCN traffic (worker
    nodes) can reach the API.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.api_endpoint_allowed_cidrs : can(cidrnetmask(c))])
    error_message = "Every entry in api_endpoint_allowed_cidrs must be a valid IPv4 CIDR."
  }
}

variable "load_balancer_allowed_cidrs" {
  description = "CIDRs allowed to reach public load balancers on TCP 443."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for c in var.load_balancer_allowed_cidrs : can(cidrnetmask(c))])
    error_message = "Every entry in load_balancer_allowed_cidrs must be a valid IPv4 CIDR."
  }
}

variable "allow_worker_internet_egress" {
  description = <<-EOT
    Allow worker nodes outbound access to the internet through the NAT gateway.
    Required to pull images from registries other than OCIR (Docker Hub,
    quay.io, docker.elastic.co). Traffic to OCI services always goes through the
    service gateway and never leaves the Oracle network.
  EOT
  type        = bool
  default     = true
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
