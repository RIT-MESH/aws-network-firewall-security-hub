# Incident response playbook

## Detect

- CloudWatch alarm fires (alert-volume-high or dropped-spikes).
- Review firewall alert log group `/aws/network-firewall/anfw-<env>/alert`.
- Use `scripts/analyze-firewall-logs.py` on an exported sample.

## Triage

1. Identify the source IP, destination, port, and matching SID.
2. Cross-reference the SID against `rules/stateful/*.rules`.
3. Determine if the flow is expected (policy test) or anomalous.

## Contain

- Add the source/destination to the prohibited IP set (`rules/ip-sets/blocked-destinations.txt`)
  or block the domain (`rules/domain-lists/blocked-domains.txt`).
- Apply with explicit approval.

## Eradicate / recover

- Rotate affected credentials if a workload was compromised.
- Remove test workloads (`enable_test_workloads = false`).

## Post-incident

- Preserve CloudWatch and S3 logs (do not delete).
- Update rules and add tests for the new indicator.
- Document the lesson in `security-decisions.md`.
