# Network security groups.
#
# One NSG per role. Rules reference each other by NSG rather than by CIDR, so
# the policy stays correct when subnets are resized and reads as "workers may
# talk to the control plane" instead of "10.0.2.0/24 may talk to 10.0.1.0/28".
#
# The rule set follows Oracle's documented requirements for an OKE cluster
# using VCN-native pod networking. Ports that look arbitrary are not:
#   6443        Kubernetes API
#   12250       OKE control plane to worker communication
#   10250       kubelet API
#   10256       kube-proxy health check, used by load balancer health probes
#   30000-32767 NodePort range
#   ICMP 3/4    "fragmentation needed", required for path MTU discovery

locals {
  # Ports the control plane needs to reach on workers and pods, and vice versa.
  node_port_min = 30000
  node_port_max = 32767

  oci_services_cidr = data.oci_core_services.all_oci_services.services[0]["cidr_block"]
}

resource "oci_core_network_security_group" "control_plane" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-nsg-control-plane"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_core_network_security_group" "workers" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-nsg-workers"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_core_network_security_group" "pods" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-nsg-pods"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

resource "oci_core_network_security_group" "load_balancer" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-nsg-load-balancer"

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
