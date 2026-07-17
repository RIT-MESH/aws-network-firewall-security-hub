#!/usr/bin/env bash
# Print local setup instructions for validation tooling. Does not modify the
# system without confirmation.
set -euo pipefail

cat <<'EOF'
AWS Network Firewall Security Hub - local bootstrap

Required:
  - Terraform >= 1.5.0, < 2.0   (https://developer.hashicorp.com/terraform/downloads)
  - Python 3.10+ with pytest     (pip install pytest)

Optional (recommended):
  - tflint      (https://github.com/terraform-linters/tflint)
  - checkov     (pip install checkov)
  - tfsec       (https://aquasecurity.github.io/tfsec/)
  - shellcheck  (https://www.shellcheck.net/)
  - yamllint    (pip install yamllint)
  - markdownlint-cli (npm install -g markdownlint-cli)
  - pre-commit  (pip install pre-commit; pre-commit install)

Validate without AWS credentials:
  make validate
  # or
  scripts/validate.sh

Never run `terraform apply` without explicit human approval.
EOF