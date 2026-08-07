# Rules for the pod NSG, used by VCN-native pod networking.
#
# Note that this is the coarse, cluster-wide layer. Per-workload restrictions
# belong in Kubernetes NetworkPolicy objects, which is where the sample app
# defines its own; see apps/sample-api/chart/templates/networkpolicy.yaml.

resource "oci_core_network_security_group_security_rule" "pods_ingress_pods" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Pod to pod traffic"
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_network_security_group.pods.id
  source_type               = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "pods_ingress_workers" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Kubelet probes and node-sourced traffic"
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_network_security_group.workers.id
  source_type               = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "pods_ingress_control_plane" {
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Control plane reaches admission and conversion webhooks"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.control_plane.id
  source_type               = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "pods_egress_pods" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Pod to pod traffic"
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = oci_core_network_security_group.pods.id
  destination_type          = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "pods_egress_workers" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Pods reach node-local services such as CoreDNS and the metadata proxy"
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "pods_egress_api" {
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Pods reach the Kubernetes API"
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.control_plane.id
  destination_type          = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "pods_egress_oci_services" {
  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "OCI Vault and Object Storage over the service gateway"
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = local.oci_services_cidr
  destination_type          = "SERVICE_CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "pods_egress_internet" {
  count = var.allow_worker_internet_egress ? 1 : 0

  network_security_group_id = oci_core_network_security_group.pods.id
  description               = "Outbound HTTPS from workloads through the NAT gateway"
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}
