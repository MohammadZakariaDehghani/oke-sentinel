terraform {
  required_version = ">= 1.9.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.26"
    }
  }

  # No backend block. This stack creates the bucket that every other stack
  # stores its state in, so its own state is local — the usual bootstrap
  # chicken-and-egg. Keep terraform.tfstate for this directory somewhere
  # durable and private, or accept that re-running it against an existing
  # bucket needs `terraform import`.
}
