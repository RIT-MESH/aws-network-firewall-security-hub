# AWS Network Firewall rules

Suricata-compatible stateful rules, native `tls.sni` domain rules, IP sets, and
a stateless rule specification for the centralized AWS Network Firewall.

## Layout

- `stateful/allow.rules`  - pass rules (non-HTTP allow)
- `stateful/deny.rules`   - drop rules (block + log)
- `stateful/alert.rules`  - alert-only rules for suspicious-but-allowed traffic
- `stateful/dns.rules`    - DNS allow rules to the approved resolver
- `domain-lists/allowed-domains.txt` - egress allowlist (used to generate tls.sni pass rules)
- `domain-lists/blocked-domains.txt`  - explicit blocklist (used to generate tls.sni drop rules)
- `ip-sets/home-networks.txt`         - workload CIDRs (documentation)
- `ip-sets/blocked-destinations.txt`  - prohibited destination CIDRs (TEST-NET)
- `stateless/stateless-rules.yaml`    - stateless rule spec (documentation)

## Rule variables

Defined in each stateful rule group `rule_variables` (IP set definitions) and exposed
to Suricata rules as `$<name>`:

| Variable | Definition |
| --- | --- |
| `$LAB_HOME_NET` | workload VPC CIDRs (production, development, shared services) |
| `$LAB_DEV_NET` | development VPC CIDR |
| `$LAB_PROD_NET` | production VPC CIDR |
| `$LAB_SHARED_NET` | shared services VPC CIDR |
| `$LAB_EXTERNAL_NET` | `0.0.0.0/0` |
| `$LAB_BLOCKED_DESTS` | prohibited destination CIDRs (TEST-NET ranges) |

`$HOME_NET`/`$EXTERNAL_NET` are intentionally NOT reused to avoid collisions with
any provider predefined variables.

## Stateful rule-evaluation order

The policy uses `stateful_rule_order = STRICT_ORDER`. Rule groups are evaluated
by ascending priority; the first matching rule's action wins and evaluation
stops. Drop actions also emit alert/flow logs (so "block and alert" is satisfied
by a single drop rule).

| Priority | Group | Type | Effect |
| --- | --- | --- | --- |
| 55 | tls-domains | Suricata `tls.sni` pass/drop | Allow listed domains (flow-level pass); drop blocked domains; drop unmatched HTTPS server responses |
| 90 | dns | 5-tuple pass | DNS to the approved resolver |
| 100 | deny | 5-tuple drop | Telnet, dev->prod, unauthorized DNS, prohibited IP set |
| 200 | alert | 5-tuple alert | Suspicious ports, outbound RDP (alert only) |
| 400 | allow | 5-tuple pass | mgmt SSH, prod->shared logging |
| default | (none) | alert_strict | Unmatched traffic is alerted; HTTPS server responses for unmatched domains are dropped by the tls-domains catch-all rule |

Stateless evaluation is independent: a stateless drop rule group (priority 1)
drops traffic to `blocked-destinations.txt` CIDRs; stateless default action is
`aws:forward_to_sfe` so all traffic reaches the stateful engine.

## Why native tls.sni rules instead of domain-list rule groups

AWS Network Firewall domain-list rule groups (ALLOWLIST/DENYLIST) evaluate TLS
SNI asynchronously. This creates a race condition with the stateful default
action:

- `drop_established` drops the ClientHello before the allowlist can match
  (allowed HTTPS times out).
- `alert_strict` passes the ClientHello before the denylist can match (blocked
  HTTPS reaches the server).

Native Suricata `tls.sni` rules set **flow-level** pass/drop verdicts. With
`alert_strict` as the stateful default:

1. The TCP handshake and ClientHello pass through (alerted by the default).
2. The `tls.sni` rule matches the SNI and sets a flow-level verdict.
3. For allowed domains, `pass` allows the entire flow (including server
   responses).
4. For blocked domains, `drop` drops the entire flow.
5. For unmatched domains, no `pass` verdict is set, so the catch-all
   `drop tcp from_server,established` rule drops the server response.

This design was validated through runtime testing: all 13 traffic tests pass
consistently (allowed HTTPS returns 200, blocked and unmatched HTTPS time out).

## SID allocation

SIDs are unique across all stateful files and the generated tls-domains rules:

| Range | File |
| --- | --- |
| 10000010-10000019 | allow.rules |
| 10000020-10000029 | deny.rules |
| 10000030-10000039 | alert.rules |
| 10000050-10000052 | tls-domains (blocked domains, generated) |
| 10000060-10000063 | tls-domains (allowed domains, generated) |
| 10000070 | tls-domains (catch-all unmatched HTTPS server response drop) |
| 10000080-10000089 | dns.rules |

Stateless groups do not use SIDs.

## Compatibility notes

AWS Network Firewall supports Suricata-compatible rules but not full Suricata
feature parity. Validate rule behavior against the deployed firewall. See
docs/limitations.md and AWS documentation on stateful rule limitations.
