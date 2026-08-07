# Module: network

The VCN that everything else sits in: four purpose-built subnets, three
gateways, and NSG-based segmentation.

## What it creates

| Resource | Purpose |
|---|---|
| VCN | `10.0.0.0/16` by default |
| Internet gateway | Egress and ingress for the public load balancer subnet |
| NAT gateway | Outbound-only internet access for private subnets |
| Service gateway | OCIR, Object Storage and KMS traffic stays on the Oracle backbone |
| Public route table | `0.0.0.0/0` → internet gateway |
| Private route table | `0.0.0.0/0` → NAT gateway, OCI services → service gateway |
| 4 subnets | load balancer (public), control plane, workers, pods |
| 4 NSGs | one per role, with rules that reference each other by group |
| Default security list | Managed and left empty, so NSGs are the only thing granting access |

## Subnet layout

With the default `10.0.0.0/16`:

| Subnet | CIDR | Public | Holds |
|---|---|---|---|
| `lb` | `10.0.0.0/24` | yes | Load balancers created by `type: LoadBalancer` Services |
| `cp` | `10.0.1.0/28` | only if `is_api_endpoint_public` | The OKE Kubernetes API endpoint |
| `workers` | `10.0.2.0/24` | no | Worker node VNICs |
| `pods` | `10.0.64.0/18` | no | One VCN address per pod |

The pod subnet is large because VCN-native pod networking gives every pod a
real VCN IP. Size it for `max nodes × max pods per node` plus headroom for
rolling updates; a `/18` covers 16,382 addresses.

## Security model

Filtering is done entirely with network security groups. The default security
list created with the VCN is adopted by Terraform and left with no rules, and
every subnet is attached to it explicitly. Because OCI evaluates security list
rules and NSG rules as a union, an empty security list means the NSGs decide
everything.

Rules reference peer NSGs rather than CIDRs wherever possible, so the policy
survives subnet resizing and reads as intent. See
`docs/decisions/0002-nsgs-over-security-lists.md` for why.

The port numbers are not arbitrary — `6443` is the Kubernetes API, `12250` is
OKE control plane communication, `10250` is the kubelet, `10256` is the
kube-proxy health check that OCI load balancer probes hit, and `30000-32767` is
the NodePort range. ICMP type 3 code 4 is allowed in both directions between
the control plane and nodes because path MTU discovery breaks without it, which
shows up as large API responses hanging rather than as an obvious error.

## Usage

```hcl
module "network" {
  source = "../../modules/network"

  compartment_id = module.compartment.id
  name_prefix    = "sentinel-dev"

  vcn_cidr                   = "10.0.0.0/16"
  is_api_endpoint_public     = true
  api_endpoint_allowed_cidrs = ["203.0.113.10/32"] # your egress address

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}
```

## Notes

- `api_endpoint_allowed_cidrs` defaults to empty. That is deliberate: with no
  entries the API endpoint is reachable only from inside the VCN, and you have
  to make an explicit decision to open it.
- Setting `allow_worker_internet_egress = false` blocks the NAT gateway and
  removes the `0.0.0.0/0` egress rules. The cluster then can only pull images
  from OCIR. That is the tighter posture, but it means mirroring
  `docker.elastic.co` images into OCIR first.
