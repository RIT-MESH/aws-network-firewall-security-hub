# Limitations

## Static validation

Static tests prove configuration intent, not runtime behavior. Packet-level
validation requires deploying in AWS.

## AWS Network Firewall rule compatibility

AWS Network Firewall supports Suricata-compatible rules but not full Suricata
feature parity. Rules must be single-line (multi-line is rejected). Confirm rule
behavior against the deployed firewall.

## Centralized inspection routing (runtime finding)

During runtime validation, the firewall appeared to receive "zero packets" and
all allowed traffic timed out, despite all route tables, Transit Gateway
associations, and firewall endpoint mappings being verified correct.

### Verified root cause (runtime evidence)

The routing was correct all along. The actual root cause was the firewall
**policy stateless default action**: `stateless_default_actions = ["aws:drop"]`
dropped every packet at the stateless engine when no stateless rule matched.
The only stateless rule group is the prohibited-destination drop. All other
traffic (allowed HTTPS, DNS, cross-VPC, etc.) matched no stateless rule, hit the
`aws:drop` default, and was dropped **before the stateful engine ran** — so the
stateful allow/deny/alert/DNS/domain-list rules never evaluated any traffic.

CloudWatch metrics (dimensions `FirewallName` + `AvailabilityZone` + `Engine`)
confirmed this: `ReceivedPackets = 2419`, `DroppedPackets = 2419` (stateless),
`PassedPackets = 0`, with zero stateful processing. This matched the original
symptom: the firewall receives packets but passes none to the stateful engine.

Two earlier false conclusions were corrected during diagnosis:

- A route-target **classification defect** (an NFW endpoint route is returned by
  `describe-route-tables` with a `vpce-` value in `GatewayId`, not
  `VpcEndpointId`) produced a false "IGW bypass" report. Fixed in
  `scripts/classify_route.py` with regression coverage.
- A **CloudWatch metric dimension defect** (querying `Firewall` instead of
  `FirewallName`) produced a false "0 packets received" report.

### Fix applied

`stateless_default_actions` and `stateless_fragment_default_actions` now default
to `["aws:forward_to_sfe"]`, so unmatched stateless traffic reaches the stateful
engine. The stateless prohibited-destination drop rule group remains attached,
and the stateful default remains `["aws:drop_strict"]`. Variable validation
rejects a bare `aws:drop` stateless default so the defect cannot recur. The
earlier AZ-index-keyed endpoint mapping hardening remains in place (it was a
real fragility, just not the root cause).

## Stateful rule defects (post-fix runtime finding) — FIXED

After the stateless-default fix (`aws:forward_to_sfe`), the stateful engine
received traffic but dropped all of it (`PassedPackets = 0`). Two stateful-rule
defects were found and fixed (commit af56b8b, applied):

1. **Approved-DNS pass rules shadowed by unauthorized-DNS deny rules (FIXED).**
   The deny rules used `$LAB_EXTERNAL_NET = 0.0.0.0/0` for destination port 53,
   which includes the shared-services CIDR. In STRICT_ORDER the deny rules
   (priority 100) evaluated before the DNS pass rules (priority 300), so
   workload DNS to the approved resolver was dropped by `sid 10000023` /
   `sid 10000025`. Fixed by raising the DNS pass rule-group priority to 90
   (above the deny priority 100). Approved DNS UDP now passes
   (`sid 10000040`); unauthorized external DNS is still dropped
   (`sid 10000023` / `sid 10000025`).

2. **TLS SNI domain-list rules could not evaluate under `drop_strict` (FIXED).**
   With `stateful_default_actions = ["aws:drop_strict"]` and the default stream
   exception policy, the stateful engine dropped the TCP SYN before the TLS
   ClientHello (SNI) arrived, so the allowed-domains ALLOWLIST and blocked-
   domains DENYLIST never evaluated. Fixed by setting
   `stream_exception_policy = "CONTINUE"` so the engine passes the TCP
   handshake until it can inspect the SNI. The stateful engine now passes
   traffic (`PassedPackets` 0 -> 13); the `drop_strict` default still denies
   unmatched traffic.

## Return-path routing defect (runtime finding) — OPEN

After the stateful fixes, allowed HTTPS and approved-DNS-TCP flows still time
out even though the firewall passes the forward direction (`PassedPackets > 0`).
Confirmed root cause: the inspection VPC **public subnet route tables** contain
only `10.0.0.0/16 -> local` and `0.0.0.0/0 -> IGW` and no spoke-CIDR routes.
When the NAT gateway DNATs a return packet to a spoke private IP (e.g.
`10.2.x.x`), the public subnet route table sends it via `0.0.0.0/0 -> IGW`, and
the IGW drops it (private destination). So the return path for allowed internet
flows is broken: the SYN passes, but the SYN-ACK never returns, the ClientHello
is never sent, and the TLS SNI domain rules cannot evaluate. This also blocks
approved-DNS-TCP (the RST return does not reach the client) and prevents
restricted-domain blocking from being identified by the DENYLIST.

Fix direction: add `spoke CIDRs -> same-AZ firewall endpoint` routes to the
inspection public subnet route tables so the NAT return goes back through the
firewall (stateful inspection) -> firewall subnet (`spoke -> TGW`) -> TGW ->
spoke. This is a route-resource addition (`aws_route`), outside the firewall-
policy/rule-group apply scope, and requires separate approval. Until it is
fixed, allowed HTTPS, approved DNS TCP, restricted-domain blocking, and
return-path symmetry cannot be validated as PASS, so the project remains
"Deployed, runtime validation incomplete."

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
