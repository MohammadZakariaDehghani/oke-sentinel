# VCN, gateways and route tables.
#
# Routing model:
#   * the load balancer subnet is public and routes 0.0.0.0/0 at the internet
#     gateway;
#   * worker and pod subnets are private and route 0.0.0.0/0 at the NAT gateway
#     so nodes can pull images, but nothing on the internet can open a
#     connection to them;
#   * traffic to OCI services (OCIR, Object Storage, KMS) is routed at the
#     service gateway instead, so it stays on the Oracle backbone and does not
#     consume NAT bandwidth.

data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = var.vcn_dns_label

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# All filtering in this VCN is done with network security groups. The default
# security list that OCI creates alongside the VCN is emptied rather than
# deleted, because it cannot be deleted while the VCN exists. Security list
# rules and NSG rules are unioned, so leaving it empty means the NSGs are the
# only thing that grants access.
resource "oci_core_default_security_list" "empty" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id
  display_name               = "${var.name_prefix}-default-sl-intentionally-empty"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-igw"
  enabled        = true

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-natgw"
  block_traffic  = !var.allow_worker_internet_egress

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-sgw"

  services {
    service_id = data.oci_core_services.all_oci_services.services[0]["id"]
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-rt-public"

  route_rules {
    description       = "Default route to the internet gateway"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-rt-private"

  route_rules {
    description       = "Egress to the internet through the NAT gateway"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  route_rules {
    description       = "OCI service traffic stays on the Oracle network"
    destination       = data.oci_core_services.all_oci_services.services[0]["cidr_block"]
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
