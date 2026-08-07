# Four subnets, each with a single job.
#
# Every subnet is attached to the intentionally-empty default security list, so
# access is decided entirely by the network security groups in nsg.tf.

locals {
  default_security_list_ids = [oci_core_vcn.this.default_security_list_id]
}

resource "oci_core_subnet" "load_balancer" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = var.subnet_cidr_load_balancer
  display_name   = "${var.name_prefix}-subnet-lb"
  dns_label      = "lb"

  route_table_id    = oci_core_route_table.public.id
  security_list_ids = local.default_security_list_ids

  prohibit_public_ip_on_vnic = false
  prohibit_internet_ingress  = false

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  depends_on = [oci_core_default_security_list.empty]
}

resource "oci_core_subnet" "control_plane" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = var.subnet_cidr_control_plane
  display_name   = "${var.name_prefix}-subnet-cp"
  dns_label      = "cp"

  # The API endpoint subnet is public only when the endpoint itself is public.
  # Even then the NSG restricts 6443 to api_endpoint_allowed_cidrs.
  route_table_id    = var.is_api_endpoint_public ? oci_core_route_table.public.id : oci_core_route_table.private.id
  security_list_ids = local.default_security_list_ids

  prohibit_public_ip_on_vnic = !var.is_api_endpoint_public
  prohibit_internet_ingress  = !var.is_api_endpoint_public

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  depends_on = [oci_core_default_security_list.empty]
}

resource "oci_core_subnet" "workers" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = var.subnet_cidr_workers
  display_name   = "${var.name_prefix}-subnet-workers"
  dns_label      = "workers"

  route_table_id    = oci_core_route_table.private.id
  security_list_ids = local.default_security_list_ids

  prohibit_public_ip_on_vnic = true
  prohibit_internet_ingress  = true

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  depends_on = [oci_core_default_security_list.empty]
}

# VCN-native pod networking gives every pod a real VCN address, which is what
# makes NSG-level policy for pod traffic possible at all. The tradeoff is
# address consumption; see docs/decisions/0002-nsgs-over-security-lists.md.
resource "oci_core_subnet" "pods" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = var.subnet_cidr_pods
  display_name   = "${var.name_prefix}-subnet-pods"
  dns_label      = "pods"

  route_table_id    = oci_core_route_table.private.id
  security_list_ids = local.default_security_list_ids

  prohibit_public_ip_on_vnic = true
  prohibit_internet_ingress  = true

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  depends_on = [oci_core_default_security_list.empty]
}
