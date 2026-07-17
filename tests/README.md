# Tests

pytest suites for repository-level validation.

- `terraform/test_structure.py` - structure, version pinning, leak guards
- `terraform/test_security.py` - S3, firewall logging, no public SSH/RDP/IPs, protection flags, IMDSv2/EBS
- `terraform/test_routing.py` - centralized inspection routing intent
- `terraform/test_naming.py` - naming convention
- `rules/test_suricata_rules.py` - unique SIDs, required metadata, expected lab rules
- `rules/test_domain_lists.py` - domain/IP-set integrity and non-overlap
- `test_utilities.py` - traffic generator and log analyzer
- `fixtures/sample-alert-logs.json` - sanitized sample logs

Static tests state their limitations; they do not prove packet-level behavior.