#!/usr/bin/env bash
# Validate firewall rule artifacts: existence, unique SIDs, required metadata,
# no placeholder SIDs, domain-list integrity, and allow/block non-overlap.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES="$ROOT/rules"
FAIL=0

note_fail() { echo "FAIL: $*" >&2; FAIL=1; }

# Existence
for f in allow.rules deny.rules alert.rules dns.rules; do
  [[ -f "$RULES/stateful/$f" ]] || note_fail "missing $RULES/stateful/$f"
done
for f in allowed-domains.txt blocked-domains.txt; do
  [[ -f "$RULES/domain-lists/$f" ]] || note_fail "missing $RULES/domain-lists/$f"
done

# Unique SIDs across all stateful rule files.
sids="$(grep -rhoE 'sid:[[:space:]]*[0-9]+' "$RULES/stateful" | grep -oE '[0-9]+' || true)"
if [[ -z "$sids" ]]; then
  note_fail "no SIDs found in stateful rules"
else
  dupes="$(printf '%s\n' "$sids" | sort | uniq -d)"
  if [[ -n "$dupes" ]]; then
    note_fail "duplicate SIDs: $dupes"
  else
    echo "OK: SIDs are unique"
  fi
fi

# No placeholder SIDs.
if printf '%s\n' "$sids" | grep -qx '1000000'; then
  note_fail "placeholder sid 1000000 present"
fi

# Required metadata in each rule file.
while IFS= read -r -d '' file; do
  grep -qE 'msg:' "$file" || note_fail "$(basename "$file") missing msg"
  grep -qE 'sid:' "$file" || note_fail "$(basename "$file") missing sid"
  grep -qE 'rev:' "$file" || note_fail "$(basename "$file") missing rev"
done < <(find "$RULES/stateful" -name '*.rules' -print0)

# Domain lists: no duplicates, no overlap.
allowed="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$RULES/domain-lists/allowed-domains.txt" | sort)"
blocked="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$RULES/domain-lists/blocked-domains.txt" | sort)"
if [[ -n "$allowed" ]] && [[ $(printf '%s\n' "$allowed" | uniq -d | wc -l) -gt 0 ]]; then
  note_fail "duplicate allowed domains"
fi
if [[ -n "$blocked" ]] && [[ $(printf '%s\n' "$blocked" | uniq -d | wc -l) -gt 0 ]]; then
  note_fail "duplicate blocked domains"
fi
overlap="$(comm -12 <(printf '%s\n' "$allowed") <(printf '%s\n' "$blocked"))"
if [[ -n "$overlap" ]]; then
  note_fail "allow/block lists overlap: $overlap"
else
  echo "OK: allow and block domain lists do not overlap"
fi

exit "$FAIL"