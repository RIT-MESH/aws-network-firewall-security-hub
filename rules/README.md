# AWS Network Firewall rules

Suricata-compatible stateful rules, domain lists, IP sets, and a stateless rule
specification for the centralized AWS Network Firewall.

## Layout

- `stateful/allow.rules`  - pass rules (non-HTTP allow)
- `stateful/deny.rules`   - drop rules (block + log)
- `stateful/alert.rules`  - alert-only rules for suspicious-but-allowed traffic
- `stateful/dns.rules`    - DNS allow rules to the approved resolver
- `domain-lists/allowed-domains.txt` - egress allowlist (ALLOWLIST)
- `domain-lists/blocked-domains.txt`  - explicit blocklist (DENYLIST)
- `ip-sets/home-networks.txt`         - workload CIDRs (documentation)
- `ip-sets/blocked-destinations.txt`  - prohibited destination CIDRs (TEST-NET)
- `stateless/stateless-rules.yaml`    - stateless rule spec (documentation)

## Rule variables

Defined as firewall policy `policy_variables` (IP set definitions) and exposed
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
| 50 | blocked-domains | DENYLIST | Drop listed domains (TLS_SNI / HTTP_HOST) |
| 60 | allowed-domains | ALLOWLIST | Allow listed domains; drop all other HTTP/HTTPS egress |
| 100 | deny | 5-tuple drop | Telnet, dev->prod, unauthorized DNS, prohibited IP set |
| 200 | alert | 5-tuple alert | Suspicious ports, outbound RDP (alert only) |
| 300 | dns | 5-tuple pass | DNS to the approved resolver |
| 400 | allow | 5-tuple pass | mgmt SSH, prod->shared logging |
| default | (none) | drop_strict | Anything unmatched is dropped |

Stateless evaluation is independent: a stateless drop rule group (priority 1)
drops traffic to `blocked-destinations.txt` CIDRs; stateless default action is
`aws:drop`.

## SID allocation

SIDs are unique across all stateful files:

| Range | File |
| --- | --- |
| 10000010-10000019 | allow.rules |
| 10000020-10000029 | deny.rules |
| 10000030-10000039 | alert.rules |
| 10000040-10000049 | dns.rules |

Domain-list and stateless groups do not use SIDs.

## Compatibility notes

AWS Network Firewall supports Suricata-compatible rules but not full Suricata
feature parity. Validate rule behavior against the deployed firewall. See
docs/limitations.md (Phase 7) and AWS documentation on stateful rule limitations.
