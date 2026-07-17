# Rules

AWS Network Firewall rule artifacts.

- `stateless/` - stateless rule definitions (YAML)
- `stateful/` - Suricata-compatible stateful rules, separated into allow, deny, alert, and DNS
- `domain-lists/` - allowed and blocked domain lists
- `ip-sets/` - home-network and blocked-destination IP sets

TODO (Phase 4): add rule files, domain lists, and IP sets. Every stateful rule
must have a unique SID, a revision number, a meaningful message, explicit
direction, an appropriate flow keyword, and a documented expected test.
