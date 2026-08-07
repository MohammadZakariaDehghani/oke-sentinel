# Bootstrap

Run this once, by hand, before `environments/dev` or `environments/prod`.

It creates the Object Storage bucket that every other stack keeps its state
in, and the defined tag namespace those stacks tag resources with. Its own
state is local, because the bucket it creates does not exist yet.

## What it creates

| Resource | Why |
|---|---|
| `oci_objectstorage_bucket` | Terraform state, versioned, no public access |
| `oci_identity_tag_namespace` | `sentinel` |
| `oci_identity_tag` ×3 | `CostCenter`, `Environment`, `Owner`, all cost-tracking |
| `oci_identity_customer_secret_key` | Optional, off by default |

## Why both freeform and defined tags

Freeform tags are arbitrary key/value pairs — useful to a human reading the
console, invisible to cost analysis. Defined tags are declared in a namespace
and can be marked `is_cost_tracking`, which is what makes them available as a
dimension in OCI Cost Analysis. Only defined tags let you answer "what did the
dev environment cost last month".

So both are applied everywhere: freeform for orientation, defined for the bill.

## Running it

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan
terraform apply
```

Take the `object_storage_namespace` and `s3_compatible_endpoint` outputs — the
environment stacks need them in their backend configuration.

## The Customer Secret Key

Terraform's `s3` backend talks to Object Storage through its S3-compatible
endpoint, which authenticates with an access key / secret key pair. In OCI that
pair is a Customer Secret Key belonging to an IAM user.

`create_customer_secret_key` defaults to `false`. The secret half is returned
exactly once, and creating it here writes it into this stack's local state file
in plaintext. Creating it in the console and pasting it straight into a
password manager avoids that. If you do set it to `true`, treat
`terraform.tfstate` in this directory as a credential.

Either way the pair is supplied to Terraform through the environment, never
through a file in this repository:

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
```

## Re-running

This stack is not idempotent against resources it did not create. If the bucket
or the tag namespace already exists, `terraform import` them rather than
letting the apply fail — tag namespaces in particular cannot be deleted, only
retired, so a duplicate name is a lasting annoyance.
