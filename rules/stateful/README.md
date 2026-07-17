# Stateful (Suricata-compatible) rules

- `allow.rules` - pass rules (non-HTTP allow)
- `deny.rules` - drop rules (block + log)
- `alert.rules` - alert-only rules for suspicious-but-allowed traffic
- `dns.rules` - DNS allow rules to the approved resolver

Unique SIDs across all files. See `../README.md` for evaluation order.
