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

## Stateful rule defects (post-fix runtime finding)

After the stateless-default fix (`aws:forward_to_sfe`), the stateful engine
receives traffic, but runtime validation found two separate stateful-rule
defects that prevent the intended allow/DNS policy from working:

1. **Approved-DNS pass rules are shadowed by the unauthorized-DNS deny rules.**
   The deny rules use `$LAB_EXTERNAL_NET = 0.0.0.0/0` for destination port 53,
   which includes the shared-services CIDR (`$LAB_SHARED_NET`). In STRICT_ORDER
   the deny rules (priority 100) evaluate before the DNS pass rules
   (priority 300), so workload DNS to the approved shared-services resolver
   (10.3.0.0/16:53) is dropped by `sid 10000023` / `sid 10000025` instead of
   passed by `sid 10000040` / `sid 10000041`. Confirmed in the ALERT log.
   Fix direction: exclude the shared-services CIDR from the unauthorized-DNS
   deny rules (e.g. a negated destination set or a higher-priority DNS pass),
   or raise the DNS pass priority above the deny priority.

2. **TLS SNI domain-list rules (allowed-domains ALLOWLIST and blocked-domains
   DENYLIST) do not pass/drop as intended under the `drop_strict` stateful
   default.** Allowed HTTPS to `example.com` (in the ALLOWLIST) is dropped by
   the stateful default (`PassedPackets = 0`), and restricted-domain HTTPS to
   `restricted.example.org` (in the DENYLIST) is dropped by the default rather
   than by the DENYLIST rule (no DENYLIST ALERT event). The TLS SNI rules appear
   not to evaluate before the default drop applied to the TCP handshake. Fix
   direction: review the stateful engine stream-exception policy and the
   domain-list rule group configuration under STRICT_ORDER with `drop_strict`,
   or add explicit stateful pass rules for the TLS handshake to the allowed
   domains.

These are stateful-rule/design defects, not routing defects, and are outside the
stateless-default fix scope. Until they are corrected, allowed HTTPS egress and
approved DNS cannot be validated as PASS, so the project remains "Deployed,
runtime validation incomplete."
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
