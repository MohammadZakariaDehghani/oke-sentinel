# OKE Sentinel — developer entry points.
#
# Every target here is also what CI runs, so a green `make lint && make test`
# locally means the pull request checks should be green too.

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

PY_PROJECTS  := tools/oci-inventory apps/sample-api
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
lint: py-lint py-type tf-fmt-check tf-lint tf-checkov ## Run every static check

.PHONY: test
test: py-test ## Run the unit tests

# ---------------------------------------------------------------------------
# Python
# ---------------------------------------------------------------------------

.PHONY: py-fmt
py-fmt: ## Apply ruff formatting and autofixes
	ruff format $(PY_PROJECTS)
	ruff check --fix $(PY_PROJECTS)

.PHONY: py-lint
py-lint: ## ruff lint + format check
	ruff check $(PY_PROJECTS)
	ruff format --check $(PY_PROJECTS)

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
		( cd "$$p" && pytest -q ) || exit 1; \
	done

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------

.PHONY: tf-fmt
tf-fmt: ## terraform fmt -recursive
	terraform fmt -recursive terraform

.PHONY: tf-fmt-check
tf-fmt-check: ## Fail if any Terraform file is unformatted
	terraform fmt -check -recursive -diff terraform

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
	@command -v tflint >/dev/null 2>&1 || { echo "tflint not installed; skipping"; exit 0; }
	tflint --chdir=terraform --recursive --config="$$(pwd)/.tflint.hcl"

# One invocation per stack, on purpose: checkov given several directories at
# once only really scans the first, and reports the rest cumulatively against
# it, so findings in the later directories are silently lost.
.PHONY: tf-checkov
tf-checkov: ## checkov static analysis of the Terraform
	@command -v checkov >/dev/null 2>&1 || { echo "checkov not installed; skipping"; exit 0; }
	@for s in $(TF_STACKS) terraform/bootstrap; do \
		echo "==> checkov $$s"; \
		checkov --config-file .checkov.yaml --directory "$$s" || exit 1; \
	done

# ---------------------------------------------------------------------------
# Kubernetes
# ---------------------------------------------------------------------------

.PHONY: k8s-render
k8s-render: ## Render every Kustomize overlay (catches build errors early)
	@for o in kubernetes/overlays/*; do \
		echo "==> kustomize build $$o"; \
		kubectl kustomize "$$o" > /dev/null || exit 1; \
	done
	@echo "all overlays render"

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

.PHONY: secrets-scan
secrets-scan: ## Re-run detect-secrets against the tracked files
	detect-secrets scan --baseline .secrets.baseline
	detect-secrets audit --report --fail-on-unaudited .secrets.baseline

# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------

.PHONY: clean
clean: ## Remove caches and build artefacts
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	rm -rf .pytest_cache .mypy_cache .ruff_cache
	find terraform -type d -name .terraform -prune -exec rm -rf {} +
