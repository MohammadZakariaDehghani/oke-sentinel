terraform {
  required_version = ">= 1.9.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.26"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # Remote state in OCI Object Storage through its S3-compatible endpoint.
  # Deliberately a partial configuration: the bucket name, endpoint and region
  # are tenancy-specific, so they come from backend.hcl at init time rather
  # than being committed.
  #
  #   terraform init -backend-config=backend.hcl
  #
  # Credentials come from the environment, never from a file:
  #   export AWS_ACCESS_KEY_ID=<customer secret key access key>
  #   export AWS_SECRET_ACCESS_KEY=<customer secret key secret>
  backend "s3" {}
}
