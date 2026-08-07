# Rules for the Kubernetes API endpoint NSG.

resource "oci_core_network_security_group_security_rule" "cp_ingress_workers_api" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Worker nodes reach the Kubernetes API"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.workers.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cp_ingress_workers_okecp" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Worker nodes reach the OKE control plane on 12250"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.workers.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cp_ingress_workers_icmp" {
  #checkov:skip=CKV2_OCI_2:ICMP type 3 code 4 only, which cannot carry TCP 3389
  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Path MTU discovery from worker nodes"
  direction                 = "INGRESS"
  protocol                  = "1"
  source                    = oci_core_network_security_group.workers.id
  source_type               = "NETWORK_SECURITY_GROUP"

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "cp_ingress_pods_api" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Pods reach the Kubernetes API directly under VCN-native pod networking"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.pods.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# Operator access. Empty by default: with no entry here the API is reachable
# only from inside the VCN.
resource "oci_core_network_security_group_security_rule" "cp_ingress_operator_api" {
  for_each = toset(var.api_endpoint_allowed_cidrs)

  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Operator access to the Kubernetes API from ${each.value}"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cp_egress_oci_services" {
  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Control plane to OCI services over the service gateway"
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

# The control plane opens connections to the kubelet (10250) and to admission
# and conversion webhooks, which can listen on any port the workload chooses.
# Oracle's reference rule set allows all TCP for this reason.
resource "oci_core_network_security_group_security_rule" "cp_egress_workers" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Control plane to kubelet and webhooks on worker nodes"
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "cp_egress_pods" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Control plane to admission webhooks running in pods"
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.pods.id
  destination_type          = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "cp_egress_workers_icmp" {
  #checkov:skip=CKV2_OCI_2:ICMP type 3 code 4 only, which cannot carry TCP 3389
  network_security_group_id = oci_core_network_security_group.control_plane.id
  description               = "Path MTU discovery to worker nodes"
  direction                 = "EGRESS"
  protocol                  = "1"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"

  icmp_options {
    type = 3
    code = 4
  }
}
