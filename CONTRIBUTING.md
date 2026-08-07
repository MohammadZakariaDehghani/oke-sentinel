# Contributing

Thanks for taking a look. This is a portfolio project, but it is set up like a
real repository — the same checks run on every pull request, and they have to
pass before anything merges.

## Getting set up

```bash
git clone https://github.com/MohammadZakariaDehghani/oke-sentinel.git
cd oke-sentinel
make setup        # installs the Python projects and the pre-commit hooks
```

`make setup` expects Python 3.11+ and [uv](https://docs.astral.sh/uv/). The
Terraform and Kubernetes tooling (`terraform`, `tflint`, `checkov`, `kubectl`,
`kind`, `helm`) is only needed for the targets that use it; `make tools-check`
reports what is missing.

## Before you push

```bash
make lint         # ruff, mypy, terraform fmt, checkov, tflint
make test         # pytest for both Python projects
```

Or let the hooks do it:

```bash
pre-commit run --all-files
```

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/). The scope should
name the area you touched:

```
feat(terraform): add network module with NSG-based segmentation
fix(k8s): correct Filebeat autodiscover hint for JSON container logs
docs(adr): record the ECK-over-Helm decision
ci: run checkov against the environment stacks only
```

Common types here: `feat`, `fix`, `docs`, `ci`, `chore`, `refactor`, `test`.

## Ground rules

**Never commit real tenancy data.** No OCIDs, API key fingerprints, private
keys, or compartment IDs. Terraform inputs go in `*.tfvars.example` with
obviously-fake placeholder values. `detect-secrets` runs as a pre-commit hook
and in CI; if it flags something benign, review it and update the baseline
rather than deleting the hook:

```bash
detect-secrets scan --baseline .secrets.baseline
```

**Everything must run.** If you add Terraform, it has to pass `terraform
validate` and `checkov`. If you add Python, it has to pass `ruff`, `mypy`, and
`pytest`. If you change the logging pipeline, the kind integration job has to
still prove that logs reach Elasticsearch.

**Keep it boring.** Clear, idiomatic code beats a clever abstraction. A module
that someone can read top to bottom is worth more than one that saves ten
lines.

## Adding a detection rule

1. Add the query to `security/detections/` following the layout of the existing
   rules (metadata block, Elasticsearch query DSL, and at least one positive and
   one negative fixture).
2. Add a test in `security/tests/` — the fixtures are indexed into the CI
   Elasticsearch and the rule must match the positive case and ignore the
   negative one.
3. Document it in `docs/detections.md`, including the MITRE ATT&CK technique if
   one applies. A rule without a written explanation of what it catches and why
   is not finished.

## Architecture decisions

Non-obvious tradeoffs go in `docs/decisions/` as a short ADR. Copy the shape of
an existing one: context, decision, consequences, and what would make us revisit
it.
