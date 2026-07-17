# Security decisions

- **Centralized inspection**: one enforcement point simplifies policy and audit.
- **No public IPs on workloads**: prevents direct internet exposure; forces egress through inspection.
- **SSM over public SSH/RDP**: no management ports exposed; IMDSv2 required.
- **STRICT_ORDER**: deterministic rule evaluation; first match wins; documented priorities.
- **Production and development separated**: blast-radius isolation; dev->prod blocked.
- **Both CloudWatch and S3**: operational visibility + long-term encrypted archival.
- **Single Terraform root with environment tfvars**: avoids duplicated drift-prone compositions; environment differences are tfvars only. Production tfvars enable protection flags.
- **Egress allowlist**: HTTP/HTTPS allowed only to `allowed-domains` (ALLOWLIST); broader egress is dropped.
- **Documentation-only test destinations**: rules and tests use RFC 5737 TEST-NET ranges and example domains; no active malicious infrastructure.
