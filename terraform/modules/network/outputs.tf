output "vcn_id" {
  description = "OCID of the VCN."
  value       = oci_core_vcn.this.id
}

output "vcn_cidr" {
  description = "CIDR block of the VCN."
  value       = var.vcn_cidr
}

output "load_balancer_subnet_id" {
  description = "OCID of the public subnet used for service load balancers."
  value       = oci_core_subnet.load_balancer.id
}

output "control_plane_subnet_id" {
  description = "OCID of the subnet holding the Kubernetes API endpoint."
  value       = oci_core_subnet.control_plane.id
}

output "worker_subnet_id" {
  description = "OCID of the private subnet holding worker node VNICs."
  value       = oci_core_subnet.workers.id
}

output "pod_subnet_id" {
  description = "OCID of the private subnet holding pod IPs."
  value       = oci_core_subnet.pods.id
}

output "control_plane_nsg_id" {
  description = "OCID of the NSG applied to the Kubernetes API endpoint."
  value       = oci_core_network_security_group.control_plane.id
}

output "worker_nsg_id" {
  description = "OCID of the NSG applied to worker nodes."
  value       = oci_core_network_security_group.workers.id
}

output "pod_nsg_id" {
  description = "OCID of the NSG applied to pod VNICs."
  value       = oci_core_network_security_group.pods.id
}

output "load_balancer_nsg_id" {
  description = "OCID of the NSG intended for service load balancers. Reference it from a Service with the oci.oraclecloud.com/oci-network-security-groups annotation."
  value       = oci_core_network_security_group.load_balancer.id
}

output "nat_gateway_id" {
  description = "OCID of the NAT gateway used for private subnet egress."
  value       = oci_core_nat_gateway.this.id
}

output "service_gateway_id" {
  description = "OCID of the service gateway used for OCI service traffic."
  value       = oci_core_service_gateway.this.id
}
