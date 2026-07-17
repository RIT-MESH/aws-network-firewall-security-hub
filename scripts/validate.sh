#!/usr/bin/env bash
# Run every available validation tool, skipping missing tools clearly.
# A missing optional tool produces a clear SKIP notice, never a misleading pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/terraform"
FAIL=0

run() {
  local name="$1"; shift
  if command -v "$name" >/dev/null 2>&1; then
    echo "==> $*"
    "$@" || FAIL=1
  else
    echo "==> SKIP $name (not installed)"
  fi
}

run terraform terraform fmt -check -recursive "$TF_DIR"
if command -v terraform >/dev/null 2>&1; then
  echo "==> terraform init -backend=false"
  (cd "$TF_DIR" && terraform init -backend=false) || FAIL=1
  echo "==> terraform validate"
  (cd "$TF_DIR" && terraform validate) || FAIL=1
fi
run tflint tflint --recursive "$TF_DIR"
run checkov checkov -d "$TF_DIR"
run tfsec tfsec "$TF_DIR"
run pytest pytest
run shellcheck shellcheck "$ROOT"/scripts/*.sh
run yamllint yamllint "$ROOT"
run markdownlint markdownlint "$ROOT"

exit "$FAIL"