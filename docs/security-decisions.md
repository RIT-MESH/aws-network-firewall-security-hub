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

## Deployment-readiness hardening

- Unauthorized external DNS is blocked on both UDP and TCP 53.
- GitHub Actions pinned to immutable commit SHAs; TFLint blocking with .tflint.hcl + AWS ruleset.
- S3 log bucket name includes account ID + Region (via data sources) for global uniqueness.
- Firewall protection enforced by check block when environment == production.
- Each Terraform module declares required_version + required_providers.
- SSM VPC endpoints (PrivateLink) deployed in workload VPCs so management traffic stays on AWS backbone (does not traverse firewall/NAT).
- CloudWatch Logs resource policy uses delivery.logs.amazonaws.com principal (verified via AWS API).
- NFW log destinations use camelCase keys (logGroup/bucketName) per AWS API.
- S3 log delivery uses SSE-S3 (AWS-managed KMS key blocks log delivery without a CMK key policy).
- Suricata rules are single-line (AWS NFW requirement).

## Runtime findings

- SSM access: resolved via PrivateLink (3/3 instances managed).
- Centralized inspection routing: defect — firewall receives 0 packets despite correct config. Requires VPC flow logs debugging.
- CloudWatch ALERT log delivery: log stream created (delivery path works).
- S3 FLOW log delivery: no objects observed (no traffic reaching firewall).
