# Domain lists

- `allowed-domains.txt` - egress ALLOWLIST (all other HTTP/HTTPS dropped)
- `blocked-domains.txt` - explicit DENYLIST

The two lists must not overlap (enforced by tests/rules/test_domain_lists.py).
