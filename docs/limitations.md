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
tables, Transit Gateway associations, and firewall endpoint mappings appearing
correct. Traffic from test instances times out before reaching the firewall.

### Static review outcome

A full static review of the routing code confirmed the intended egress, return,
and cross-VPC paths are correct: workload app subnets default to the Transit
Gateway; the workload TGW route table forwards 0.0.0.0/0 to the inspection
attachment; the inspection TGW attachment subnet route tables forward
0.0.0.0/0 to the per-AZ firewall endpoint; the firewall subnet route tables
forward 0.0.0.0/0 to the per-AZ NAT Gateway and spoke CIDRs back to the Transit
Gateway; appliance mode is enabled only on the inspection attachment (the
standard, correct configuration).

### Leading root-cause hypotheses (require runtime diagnosis)

1. **Endpoint-to-AZ mapping fragility (now hardened).** The original code coupled
   the inspection TGW route tables and the firewall endpoints positionally
   (`firewall_endpoint_ids[count.index]` aligned with a sorted-key route-table
   list). This relies on two independently-ordered structures coincidentally
   matching. A mismatch (e.g. from unordered `sync_states` or an AZ-name/zone-id
   format difference) would silently route an inspection TGW attachment subnet in
   AZ N to the firewall endpoint in AZ M, after which the stateful firewall and
   appliance-mode symmetry drop the flow without it appearing as "received" on
   the expected endpoint. The mapping has been rewritten to be explicit and
   AZ-index-keyed (see the next section).
2. **Per-AZ `tgw -> firewall` route absent or blackhole at test time.** If the
   firewall endpoints were not yet IN_SYNC when traffic tests ran, the
   `0.0.0.0/0 -> vpc_endpoint` route exists in the route table but the endpoint
   is not installed, so traffic blackholes before the firewall. A
   `firewall_endpoint_per_az` check block and an extended `scripts/test-routes.sh`
   now make this detectable before traffic tests.
3. **TGW appliance-mode AZ asymmetry or a propagation issue** not visible in
   static validation, requiring VPC flow logs and/or packet capture.

### Hardening applied (static fix)

- The inspection-routing module now receives `firewall_endpoint_ids_by_az` (a
  `map(string)` keyed by AZ index) instead of a positional `list(string)`. The
  `tgw_to_firewall` route aligns the route table and the endpoint by the SAME AZ
  key (`each.key`), eliminating positional coupling.
- The network-firewall module exports `endpoint_ids_by_az` and declares a
  `firewall_endpoint_per_az` check block that fails loudly at apply time if any
  AZ is missing exactly one endpoint.
- `scripts/test-routes.sh` now prints/executes read-only checks for: the
  inspection TGW attachment subnet `0.0.0.0/0 -> firewall endpoint` routes
  (including route State), firewall endpoint-to-AZ alignment, firewall
  IN_SYNC/READY status, and NAT Gateway state.

### Remaining runtime work

Because the AWS resources were destroyed after the prior test (Terraform state is
empty), the hypotheses above cannot be confirmed without a redeployment. After
an approved apply, run `scripts/test-routes.sh --run` BEFORE traffic tests to
confirm the per-AZ routes are active and endpoints are IN_SYNC, then proceed with
the runtime validation matrix. Do not mark tests PASS without packet-level
evidence.

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
