# Module: ocir

Container repositories in the OCI Registry, plus the IAM that lets the cluster
pull from them without a stored password.

## What it creates

| Resource | Notes |
|---|---|
| `oci_artifacts_container_repository` | One per entry in `repositories`, immutable by default |
| `oci_identity_dynamic_group` | Optional. Matches the worker node instances |
| `oci_identity_policy` | Optional. Grants that group `read repos` in the compartment |

## Why repositories are declared instead of auto-created

OCIR creates a repository on first push. That works, but it means the two
properties that matter — whether the repository is public, and whether tags can
be overwritten — are decided by whoever pushed first, silently. Declaring them
here makes both reviewable.

`is_immutable = true` is the default. It is the setting that prevents
`app:v1.2.3` from meaning different bytes tomorrow than it does today, which is
the failure mode that makes an incident timeline impossible to reconstruct.

## Pull authentication

The usual approach is an auth token in an `imagePullSecret`. That token is a
long-lived credential in cluster state, it is not scoped to a repository, and
rotating it means touching every namespace that references it.

Instead this module creates a dynamic group matching the worker node instances
and a policy granting it `read repos`. Nodes then authenticate as instance
principals and no registry credential exists in Kubernetes at all.

Dynamic groups are tenancy-scoped, so `tenancy_id` is required — a dynamic
group cannot be created inside the workload compartment even though the policy
that references it can.

## Usage

```hcl
module "ocir" {
  source = "../../modules/ocir"

  compartment_id = module.compartment.id
  tenancy_id     = var.tenancy_ocid
  name_prefix    = "sentinel-dev"

  repositories = {
    "sample-api" = {
      description = "Sample workload that emits structured JSON logs and Prometheus metrics."
    }
    "oci-inventory" = {
      description = "Governance CLI that inventories OCI resources and indexes findings."
    }
  }

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}
```

Images then push to
`<region-key>.ocir.io/<tenancy-namespace>/sentinel-dev/sample-api:<tag>`. The
tenancy namespace is not an OCID and is not secret, but it is tenancy-specific,
so it is supplied as a variable in the environment stacks rather than written
into the repository.
