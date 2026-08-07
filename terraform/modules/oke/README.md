# Module: oke

The managed Kubernetes cluster, its node pool, and the plumbing that gets
Kubernetes audit events out of a control plane you do not own.

## What it creates

| Resource | Notes |
|---|---|
| `oci_containerengine_cluster` | Enhanced cluster, VCN-native pod networking, dashboard and Tiller add-ons off |
| `oci_containerengine_node_pool` | Spread across every availability domain, nodes in the private subnet |
| `oci_streaming_stream_pool` / `oci_streaming_stream` | Optional. Kafka-compatible buffer for audit events |
| `oci_sch_service_connector` | Optional. OCI Audit → stream |
| `oci_identity_policy` | Optional. Lets the connector publish to the stream |

Everything network-facing is passed in from the `network` module. This module
never creates a subnet or an NSG.

## Node image selection

Hardcoding an image OCID means the code goes stale every time Oracle publishes
a patch build. Instead the module reads `oci_containerengine_node_pool_option`
and picks the newest Oracle Linux 8 image matching `kubernetes_version` and the
shape architecture. Set `node_image_id` to override.

If nothing matches, a `precondition` fails at plan time with a message telling
you what to check, rather than passing a null OCID to the API at apply time.

## Audit logs on a managed control plane

This is the part people usually get wrong when they move a detection pipeline
onto OKE.

On a self-managed cluster you pass `--audit-log-path` and `--audit-policy-file`
to the API server and tail the resulting file. OKE runs the control plane, so
neither flag is available to you. Audit events go to the OCI Audit service, and
getting them into Elasticsearch means:

```
OCI Audit → Service Connector Hub → OCI Streaming → Filebeat (kafka input) → Elasticsearch
```

Set `enable_audit_log_export = true` to create the stream, the connector and
the IAM policy. `_Audit` in the connector source is a well-known log group
identifier meaning "this compartment's audit log", not an OCID.

The kind and local paths do not use any of this: there the API server is ours,
`security/audit-policy.yaml` is mounted, and Filebeat tails the file. Both
paths land documents in the same shape, so the detection rules in
`security/detections/` work against either.

## Sizing

`node_memory_gbs` defaults to 32 because Elasticsearch is the memory-hungry
tenant, not because a demo needs it. See the sizing table in the root README
before changing it — a data node with a 4 GB heap on a 8 GB node will start,
run for a day, and then fall over during a shard relocation.

`max_pods_per_node` matters more than it looks under VCN-native pod
networking: each node pre-allocates that many addresses from the pod subnet, so
the subnet has to hold `nodes × max_pods_per_node` addresses, not just the pods
you actually run.

## Usage

```hcl
module "oke" {
  source = "../../modules/oke"

  compartment_id     = module.compartment.id
  tenancy_id         = var.tenancy_ocid
  name_prefix        = "sentinel-dev"
  kubernetes_version = "v1.35.2"

  vcn_id                  = module.network.vcn_id
  control_plane_subnet_id = module.network.control_plane_subnet_id
  control_plane_nsg_id    = module.network.control_plane_nsg_id
  load_balancer_subnet_id = module.network.load_balancer_subnet_id
  worker_subnet_id        = module.network.worker_subnet_id
  worker_nsg_id           = module.network.worker_nsg_id
  pod_subnet_id           = module.network.pod_subnet_id
  pod_nsg_id              = module.network.pod_nsg_id

  node_pool_size  = 3
  node_memory_gbs = 32

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}
```

After apply, the `kubeconfig_command` output gives you the exact `oci ce
cluster create-kubeconfig` invocation for this cluster.
