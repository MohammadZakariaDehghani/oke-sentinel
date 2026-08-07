# Module: vault

An OCI Vault, a master encryption key, generated secrets, and the workload
identity that lets one Kubernetes service account read them.

## What it creates

| Resource | Notes |
|---|---|
| `oci_kms_vault` | `DEFAULT` (shared) unless you ask for `VIRTUAL_PRIVATE` |
| `oci_kms_key` | AES-256, `SOFTWARE` protection by default |
| `random_password` + `oci_vault_secret` | One per entry in `generated_secrets` |
| `oci_identity_dynamic_group` | Optional. Matches one service account in one namespace |
| `oci_identity_policy` | Optional. Grants that group `read secret-bundles` |

## Secret values are generated, not supplied

There is no variable for a secret's value. A value passed into Terraform has to
exist somewhere first — a tfvars file, a CI variable, a shell history — and each
of those is a copy that outlives its usefulness. Generating means the copies
are the vault and the state file, and nothing else.

**The state file caveat is real.** `random_password` results are stored in
Terraform state in plaintext. That is why the backend for these stacks is an
Object Storage bucket with server-side encryption and no public access, and why
the bucket is not the same place anything else is published. If that tradeoff
is unacceptable for your environment, generate the secret out of band and
import it, or let a bootstrap Job in the cluster write it.

## Workload identity

The External Secrets Operator needs to authenticate to OCI. The obvious way is
to mount an OCI API signing key — a private key living in a Kubernetes Secret
whose only purpose is to fetch other Kubernetes Secrets. That is a credential
guarding credentials, and it has to be rotated by hand.

Workload identity removes it. The cluster mints a token for one service
account, and OCI IAM evaluates it against this matching rule:

```
ALL {
  resource.type = 'workload',
  resource.compartment.id = '<compartment>',
  resource.namespace = 'external-secrets',
  resource.serviceaccount.name = 'external-secrets'
}
```

Every workload matching that rule gets the policy, so the rule is the blast
radius. It is scoped to one service account in one namespace on purpose — a
rule matching the whole cluster would let any pod that can create a service
account read every secret in the compartment.

The policy grants `read secret-bundles`, which returns secret values, and
`read vaults`. It deliberately does not grant `secret-family`, which would also
allow listing and managing secrets.

Workload identity requires an enhanced cluster, which is why the `oke` module
defaults to `ENHANCED_CLUSTER`.

## Usage

```hcl
module "vault" {
  source = "../../modules/vault"

  compartment_id = module.compartment.id
  tenancy_id     = var.tenancy_ocid
  name_prefix    = "sentinel-dev"

  generated_secrets = {
    "elastic-superuser-password" = {
      length      = 32
      description = "Password for the Elasticsearch elastic user."
    }
  }

  workload_namespace       = "external-secrets"
  workload_service_account = "external-secrets"

  freeform_tags = local.freeform_tags
  defined_tags  = local.defined_tags
}
```

The generated value never appears in an output. The operator reads it from the
vault at runtime; see `kubernetes/base/external-secrets/`.
