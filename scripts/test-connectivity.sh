#!/usr/bin/env bash
# Safe connectivity test runner. Uses the Python scenario tool with explicit,
# documentation-only destinations only. Never scans arbitrary networks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="${PYTHON:-python3}"
DRY="--dry-run"
if [[ "${1:-}" == "--run" ]]; then DRY=""; fi

FAIL=0
for sc in allowed-https blocked-telnet blocked-domain unauthorized-dns; do
  if ! "$PY" "$ROOT/scripts/generate-test-traffic.py" --scenario "$sc" $DRY; then
    FAIL=1
  fi
done
exit "$FAIL"