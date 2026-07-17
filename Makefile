.RECIPEPREFIX := >
.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

TF_DIR := terraform
RULES_DIR := rules
SCRIPTS_DIR := scripts

.PHONY: help validate tf-fmt tf-init tf-validate tflint checkov tfsec pytest shellcheck yamllint markdownlint pre-commit fmt clean

help: ## Show this help
>@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

validate: tf-fmt tf-init tf-validate tflint checkov tfsec pytest shellcheck yamllint markdownlint ## Run every available validation tool, skipping missing ones

tf-fmt: ## terraform fmt -check -recursive
>@if command -v terraform >/dev/null 2>&1; then \
    echo "==> terraform fmt -check -recursive"; \
    terraform fmt -check -recursive; \
  else echo "==> SKIP terraform fmt (terraform not installed)"; fi

tf-init: ## terraform init -backend=false
>@if command -v terraform >/dev/null 2>&1; then \
    echo "==> terraform init -backend=false (in $(TF_DIR))"; \
    (cd $(TF_DIR) && terraform init -backend=false); \
  else echo "==> SKIP terraform init (terraform not installed)"; fi

tf-validate: ## terraform validate
>@if command -v terraform >/dev/null 2>&1; then \
    echo "==> terraform validate (in $(TF_DIR))"; \
    (cd $(TF_DIR) && terraform validate); \
  else echo "==> SKIP terraform validate (terraform not installed)"; fi

tflint: ## tflint --recursive
>@if command -v tflint >/dev/null 2>&1; then \
    echo "==> tflint --recursive"; \
    tflint --recursive; \
  else echo "==> SKIP tflint (not installed)"; fi

checkov: ## checkov -d terraform
>@if command -v checkov >/dev/null 2>&1; then \
    echo "==> checkov -d $(TF_DIR)"; \
    checkov -d $(TF_DIR); \
  else echo "==> SKIP checkov (not installed)"; fi

tfsec: ## tfsec terraform
>@if command -v tfsec >/dev/null 2>&1; then \
    echo "==> tfsec $(TF_DIR)"; \
    tfsec $(TF_DIR); \
  else echo "==> SKIP tfsec (not installed)"; fi

pytest: ## pytest
>@if command -v pytest >/dev/null 2>&1; then \
    echo "==> pytest"; \
    pytest; \
  else echo "==> SKIP pytest (not installed)"; fi

shellcheck: ## shellcheck scripts/*.sh
>@if command -v shellcheck >/dev/null 2>&1; then \
    echo "==> shellcheck $(SCRIPTS_DIR)/*.sh"; \
    shellcheck $(SCRIPTS_DIR)/*.sh; \
  else echo "==> SKIP shellcheck (not installed)"; fi

yamllint: ## yamllint .
>@if command -v yamllint >/dev/null 2>&1; then \
    echo "==> yamllint ."; \
    yamllint .; \
  else echo "==> SKIP yamllint (not installed)"; fi

markdownlint: ## markdownlint .
>@if command -v markdownlint >/dev/null 2>&1; then \
    echo "==> markdownlint ."; \
    markdownlint .; \
  else echo "==> SKIP markdownlint (not installed)"; fi

pre-commit: ## pre-commit run --all-files
>@if command -v pre-commit >/dev/null 2>&1; then \
    echo "==> pre-commit run --all-files"; \
    pre-commit run --all-files; \
  else echo "==> SKIP pre-commit (not installed)"; fi

fmt: ## terraform fmt -recursive (write)
>@if command -v terraform >/dev/null 2>&1; then \
    echo "==> terraform fmt -recursive"; \
    terraform fmt -recursive; \
  else echo "==> SKIP terraform fmt (terraform not installed)"; fi

clean: ## Remove local Terraform and Python artifacts
>rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl
>find . -type d -name __pycache__ -prune -exec rm -rf {} +
>rm -rf .pytest_cache
