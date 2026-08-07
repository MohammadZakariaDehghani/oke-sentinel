## What this changes

<!-- One or two sentences. What is different after this merges? -->

## Why

<!-- The problem being solved. Link an issue or an ADR if there is one. -->

## How it was verified

<!-- Be specific. "Ran make lint" is fine; "looks right" is not. -->

- [ ] `make lint` passes (ruff, mypy, terraform fmt, checkov, tflint)
- [ ] `make test` passes
- [ ] `terraform plan` reviewed for the affected stack, and the diff is what I expected
- [ ] Kubernetes changes applied to a kind cluster or a dev cluster, not just rendered

## Checklist

- [ ] No real OCIDs, fingerprints, keys, or tenancy identifiers are in the diff
- [ ] New Terraform inputs are documented and added to `terraform.tfvars.example`
- [ ] New detection rules are covered by a test and documented in `docs/detections.md`
- [ ] A non-obvious tradeoff in this change is recorded in `docs/decisions/`
- [ ] README updated if the quickstart or architecture changed

## Notes for the reviewer

<!-- Anything you want looked at closely, or anything deliberately left out. -->
