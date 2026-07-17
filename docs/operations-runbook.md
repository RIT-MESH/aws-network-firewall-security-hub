# Operations runbook

## Daily checks

- CloudWatch dashboard `anfw-<env>-firewall`: dropped/passed/received packets.
- Alarms: alert-volume-high, dropped-spikes.
- S3 log bucket object count growth; lifecycle transitions.

## Add a blocked domain

1. Append to `rules/domain-lists/blocked-domains.txt`.
2. Ensure it is not already in `allowed-domains.txt`.
3. Run `scripts/test-firewall-rules.sh` and `pytest tests/rules`.
4. Plan and apply with explicit approval.

## Add an allowed domain

Append to `rules/domain-lists/allowed-domains.txt` and validate as above.

## Rotate a NAT Gateway EIP

NAT EIPs are managed by the inspection-routing module. Plan/apply changes with
explicit approval; note egress IP changes affect allowlists at destinations.

## Change a rule variable (CIDR)

Edit `terraform/locals.tf` `rule_variables` (or the VPC CIDR variables) and
re-plan. Changing CIDRs requires re-validating routing and rules.

## Disable test workloads

Set `enable_test_workloads = false` and apply.

## Troubleshooting

See `firewall-logging.md` for log troubleshooting.