# Rules for the worker node NSG.

resource "oci_core_network_security_group_security_rule" "workers_ingress_workers" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Node to node traffic"
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_network_security_group.workers.id
  source_type               = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_pods" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Pods reach services and daemons on their node"
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_network_security_group.pods.id
  source_type               = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_control_plane" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Control plane to kubelet and webhooks"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.control_plane.id
  source_type               = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_control_plane_icmp" {
  #checkov:skip=CKV2_OCI_2:ICMP type 3 code 4 only, which cannot carry TCP 3389
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Path MTU discovery from the control plane"
  direction                 = "INGRESS"
  protocol                  = "1"
  source                    = oci_core_network_security_group.control_plane.id
  source_type               = "NETWORK_SECURITY_GROUP"

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_lb_nodeports" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Load balancer to NodePort services"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.load_balancer.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = local.node_port_min
      max = local.node_port_max
    }
  }
}

resource "oci_core_network_security_group_security_rule" "workers_ingress_lb_healthcheck" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Load balancer health checks against kube-proxy"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.load_balancer.id
  source_type               = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 10256
      max = 10256
    }
  }
}

# Oracle's reference rule set allows ICMP 3/4 from 0.0.0.0/0. Restricting it to
# the VCN keeps path MTU discovery working for in-cluster traffic without
# accepting ICMP from the internet.
resource "oci_core_network_security_group_security_rule" "workers_ingress_vcn_icmp" {
  #checkov:skip=CKV2_OCI_2:ICMP type 3 code 4 only, which cannot carry TCP 3389
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Path MTU discovery from inside the VCN"
  direction                 = "INGRESS"
  protocol                  = "1"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "workers_egress_workers" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Node to node traffic"
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "workers_egress_pods" {
  #checkov:skip=CKV2_OCI_2:peer is a network security group inside the VCN, not a CIDR, so nothing is reachable from outside the cluster
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Node to pod traffic, including kubelet probes"
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = oci_core_network_security_group.pods.id
  destination_type          = "NETWORK_SECURITY_GROUP"
}

resource "oci_core_network_security_group_security_rule" "workers_egress_api" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Worker nodes reach the Kubernetes API"
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

resource "oci_core_network_security_group_security_rule" "workers_egress_okecp" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Worker nodes reach the OKE control plane on 12250"
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.control_plane.id
  destination_type          = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

resource "oci_core_network_security_group_security_rule" "workers_egress_control_plane_icmp" {
  #checkov:skip=CKV2_OCI_2:ICMP type 3 code 4 only, which cannot carry TCP 3389
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Path MTU discovery to the control plane"
  direction                 = "EGRESS"
  protocol                  = "1"
  destination               = oci_core_network_security_group.control_plane.id
  destination_type          = "NETWORK_SECURITY_GROUP"

  icmp_options {
    type = 3
    code = 4
  }
}

resource "oci_core_network_security_group_security_rule" "workers_egress_oci_services" {
  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "OCIR, Object Storage and KMS over the service gateway"
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

resource "oci_core_network_security_group_security_rule" "workers_egress_internet" {
  count = var.allow_worker_internet_egress ? 1 : 0

  network_security_group_id = oci_core_network_security_group.workers.id
  description               = "Image pulls from public registries through the NAT gateway"
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
