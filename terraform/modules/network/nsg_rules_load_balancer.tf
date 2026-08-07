# Rules for the load balancer NSG.
#
# Only 443 is accepted. There is no port 80 rule: TLS termination happens at the
# load balancer and there is no plaintext listener to redirect from.

resource "oci_core_network_security_group_security_rule" "lb_ingress_https" {
  for_each = toset(var.load_balancer_allowed_cidrs)

  network_security_group_id = oci_core_network_security_group.load_balancer.id
  description               = "HTTPS from ${each.value}"
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_egress_nodeports" {
  network_security_group_id = oci_core_network_security_group.load_balancer.id
  description               = "Forward to NodePort services on the worker nodes"
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = local.node_port_min
      max = local.node_port_max
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_egress_healthcheck" {
  network_security_group_id = oci_core_network_security_group.load_balancer.id
  description               = "Health check kube-proxy on the worker nodes"
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = oci_core_network_security_group.workers.id
  destination_type          = "NETWORK_SECURITY_GROUP"

  tcp_options {
    destination_port_range {
      min = 10256
      max = 10256
    }
  }
}
