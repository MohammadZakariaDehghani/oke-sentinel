# The OKE cluster.
#
# Everything that faces the network is handed in from the network module: the
# API endpoint sits in the control plane subnet behind its own NSG, and the
# load balancer subnet is the only public surface.

resource "oci_containerengine_cluster" "this" {
  #checkov:skip=CKV2_OCI_6:PodSecurityPolicy was removed in Kubernetes 1.25 and cannot be enabled on any version this module supports. Workload hardening is enforced by Pod Security Admission labels on the namespaces instead.
  compartment_id     = var.compartment_id
  name               = "${var.name_prefix}-oke"
  kubernetes_version = var.kubernetes_version
  vcn_id             = var.vcn_id
  type               = var.cluster_type

  endpoint_config {
    subnet_id            = var.control_plane_subnet_id
    nsg_ids              = [var.control_plane_nsg_id]
    is_public_ip_enabled = var.is_api_endpoint_public
  }

  # VCN-native pod networking. Pod addresses come from the pod subnet rather
  # than an overlay, which is what makes NSG policy for pod traffic possible.
  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  options {
    service_lb_subnet_ids = [var.load_balancer_subnet_id]

    kubernetes_network_config {
      # pods_cidr is deliberately unset: under VCN-native pod networking the
      # pod subnet supplies addresses and setting an overlay CIDR here is
      # meaningless.
      services_cidr = var.services_cidr
    }

    add_ons {
      # Both of these are long-standing attack surface and neither is needed.
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    admission_controller_options {
      # PodSecurityPolicy was removed in Kubernetes 1.25. Workload hardening is
      # enforced with Pod Security Admission labels on the namespaces instead;
      # see kubernetes/base/namespaces.yaml.
      is_pod_security_policy_enabled = false
    }

    persistent_volume_config {
      freeform_tags = var.freeform_tags
      defined_tags  = var.defined_tags
    }

    service_lb_config {
      freeform_tags = var.freeform_tags
      defined_tags  = var.defined_tags
    }
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
