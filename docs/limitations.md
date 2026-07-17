# Limitations

## Static validation

Static tests prove configuration intent, not runtime behavior. Packet-level
validation requires deploying in AWS.

## AWS Network Firewall rule compatibility

AWS Network Firewall supports Suricata-compatible rules but not full Suricata
feature parity. Rules must be single-line (multi-line is rejected). Confirm rule
behavior against the deployed firewall.

## Centralized inspection routing (runtime finding)

During runtime validation, the firewall received zero packets despite all route
tables, Transit Gateway associations, and firewall endpoint mappings being
verified correct. Traffic from test instances times out and does not reach the
firewall. This is a runtime defect that requires VPC flow logs and/or packet
capture to diagnose. Possible causes include a subtle Transit Gateway appliance-
mode interaction or a route-table propagation issue not visible in static
validation.

## SSM access (resolved)

SSM access was initially blocked by the egress allowlist (no SSM VPC endpoints).
This was resolved by deploying PrivateLink interface VPC endpoints for ssm,
ssmmessages, and ec2messages in each workload VPC. SSM management traffic now
stays on the AWS backbone and does not traverse the firewall.

## CloudWatch log field names

Metric-filter field names assume the published AWS schema; verify against
deployed logs.

## Logging-delivery alarm

A dedicated logging-delivery alarm is not implemented (no reliable built-in
metric); monitor via CloudWatch Logs Insights.

## S3 log bucket name

Uses account ID and Region suffix (via data sources, not hardcoded) for global
uniqueness.

## Pre-commit hook versions

Pinned but should be refreshed periodically.
