# OKE Sentinel — developer entry points.
#
# Every target here is also what CI runs, so a green `make lint && make test`
# locally means the pull request checks should be green too.

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Python projects are discovered rather than listed, so a target does not fail
# just because a project has not been written yet. `wildcard` yields nothing for
# a path that does not exist.
PY_PROJECTS  := $(patsubst %/pyproject.toml,%,$(wildcard tools/*/pyproject.toml apps/*/pyproject.toml))
TF_STACKS    := terraform/environments/dev terraform/environments/prod
KIND_CLUSTER := oke-sentinel

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

.PHONY: setup
setup: ## Install Python projects (editable, with dev extras) and git hooks
	@for p in $(PY_PROJECTS); do \
		echo "==> installing $$p"; \
		uv pip install --python $$(command -v python3) -e "$$p[dev]" || exit 1; \
	done
	uv pip install --python $$(command -v python3) -r security/tests/requirements.txt
	@command -v pre-commit >/dev/null 2>&1 && pre-commit install || \
		echo "pre-commit not installed; skipping hook install"

.PHONY: tools-check
tools-check: ## Report which optional tools are available
	@for t in terraform tflint checkov kubectl kind helm trivy uv ruff mypy pytest; do \
		if command -v $$t >/dev/null 2>&1; then \
			printf "  \033[32m✓\033[0m %-10s %s\n" "$$t" "$$($$t --version 2>&1 | head -1)"; \
		else \
			printf "  \033[31m✗\033[0m %-10s not installed\n" "$$t"; \
		fi; \
	done

# ---------------------------------------------------------------------------
# Aggregates
# ---------------------------------------------------------------------------

.PHONY: fmt
fmt: py-fmt tf-fmt ## Format everything in place

.PHONY: lint
lint: py-lint py-type tf-fmt-check tf-lint tf-checkov k8s-render ## Run every static check

.PHONY: test
test: py-test detections-test ## Run the unit tests

# ---------------------------------------------------------------------------
# Python
# ---------------------------------------------------------------------------

.PHONY: py-fmt
py-fmt: ## Apply ruff formatting and autofixes
	ruff format $(PY_PROJECTS) security
	ruff check --fix $(PY_PROJECTS) security

.PHONY: py-lint
py-lint: ## ruff lint + format check
	ruff check $(PY_PROJECTS) security
	ruff format --check $(PY_PROJECTS) security

.PHONY: py-type
py-type: ## mypy for each Python project
	@for p in $(PY_PROJECTS); do \
		echo "==> mypy $$p"; \
		( cd "$$p" && mypy src ) || exit 1; \
	done

.PHONY: py-test
py-test: ## pytest for each Python project
	@for p in $(PY_PROJECTS); do \
		echo "==> pytest $$p"; \
		( cd "$$p" && python3 -m pytest -q ) || exit 1; \
	done

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------
#
# These targets skip with a message when the tool is absent, so someone working
# only on the Python side can still run `make lint`. CI installs every tool, so
# nothing is skipped there — see .github/workflows/. A skip is printed loudly
# rather than silently for exactly this reason.
#
# Note the shape of each guard: one `if`, one shell. Make gives every recipe
# line its own shell, so a `command -v ... || exit 0` guard on a separate line
# skips nothing and the tool runs anyway.

.PHONY: tf-fmt
tf-fmt: ## terraform fmt -recursive
	@if command -v terraform >/dev/null 2>&1; then \
		terraform fmt -recursive terraform; \
	else \
		echo "SKIPPED: terraform is not installed"; \
	fi

.PHONY: tf-fmt-check
tf-fmt-check: ## Fail if any Terraform file is unformatted
	@if command -v terraform >/dev/null 2>&1; then \
		terraform fmt -check -recursive -diff terraform; \
	else \
		echo "SKIPPED: terraform is not installed"; \
	fi

.PHONY: tf-init
tf-init: ## terraform init for each stack, without configuring the backend
	@for s in $(TF_STACKS); do \
		echo "==> init $$s"; \
		terraform -chdir="$$s" init -backend=false -input=false || exit 1; \
	done

.PHONY: tf-validate
tf-validate: tf-init ## terraform validate for each stack
	@for s in $(TF_STACKS); do \
		echo "==> validate $$s"; \
		terraform -chdir="$$s" validate || exit 1; \
	done

.PHONY: tf-lint
tf-lint: ## tflint across the modules and stacks
	@# One shell, not two: each recipe line gets its own shell, so an `exit 0`
	@# guard on its own line skips nothing and the tool still runs (and fails
	@# with 127 when it is absent).
	@if command -v tflint >/dev/null 2>&1; then \
		tflint --chdir=terraform --recursive --config="$$(pwd)/.tflint.hcl"; \
	else \
		echo "SKIPPED: tflint is not installed"; \
	fi

# One invocation per stack, on purpose: checkov given several directories at
# once only really scans the first, and reports the rest cumulatively against
# it, so findings in the later directories are silently lost.
.PHONY: tf-checkov
tf-checkov: ## checkov static analysis of the Terraform
	@if ! command -v checkov >/dev/null 2>&1; then \
		echo "SKIPPED: checkov is not installed"; \
		exit 0; \
	fi; \
	for s in $(TF_STACKS) terraform/bootstrap; do \
		echo "==> checkov $$s"; \
		checkov --config-file .checkov.yaml --directory "$$s" || exit 1; \
	done

# ---------------------------------------------------------------------------
# Kubernetes
# ---------------------------------------------------------------------------

.PHONY: k8s-render
k8s-render: ## Render every Kustomize overlay (catches build errors early)
	@if ! command -v kubectl >/dev/null 2>&1; then \
		echo "SKIPPED: kubectl is not installed"; \
		exit 0; \
	fi; \
	for o in kubernetes/overlays/*; do \
		echo "==> kustomize build $$o"; \
		kubectl kustomize "$$o" > /dev/null || exit 1; \
	done; \
	echo "all overlays render"

.PHONY: kind-up
kind-up: ## Create the local kind cluster used by the integration path
	kind create cluster --name $(KIND_CLUSTER) --config ci/kind-cluster.yaml

.PHONY: kind-down
kind-down: ## Delete the local kind cluster
	kind delete cluster --name $(KIND_CLUSTER)

.PHONY: local-stack
local-stack: ## Install ECK, single-node Elasticsearch, Kibana and the sample app on kind
	./ci/scripts/install-local-stack.sh

.PHONY: local-verify
local-verify: ## Assert that container logs are reaching Elasticsearch
	./ci/scripts/verify-logs.sh

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------

.PHONY: detections-test
detections-test: ## Structural tests for the detection rules (no Elasticsearch needed)
	python3 -m pytest security/tests/test_rule_definitions.py -q

.PHONY: detections-test-integration
detections-test-integration: ## Run every detection rule against a live Elasticsearch
	@test -n "$$ES_URL" || { echo "set ES_URL (and ES_PASSWORD) first"; exit 1; }
	python3 -m pytest security/tests -q

.PHONY: secrets-scan
secrets-scan: ## Re-run detect-secrets and fail on anything unreviewed
	./ci/scripts/secrets-scan.sh

# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------

.PHONY: clean
clean: ## Remove caches and build artefacts
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	rm -rf .pytest_cache .mypy_cache .ruff_cache
	find terraform -type d -name .terraform -prune -exec rm -rf {} +
