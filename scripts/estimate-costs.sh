#!/usr/bin/env bash
# Print the cost-relevant AWS components and point to current pricing.
# This script never prints fixed price figures; always review AWS pricing.
set -euo pipefail

cat <<'EOF'
AWS Network Firewall Security Hub - cost considerations

Components that may incur cost when deployed:
  - AWS Network Firewall endpoints (per-endpoint hourly + per-GB processing)
  - AWS Transit Gateway attachments (hourly) + data processing (per-GB)
  - NAT Gateways (per-endpoint hourly + per-GB data processing)
  - CloudWatch Logs ingestion and retention
  - S3 storage and lifecycle transitions for log archival
  - EC2 test instances (only when enable_test_workloads = true)
  - Cross-AZ data transfer

Review current pricing before deploying:
  https://aws.amazon.com/network-firewall/pricing/
  https://aws.amazon.com/vpc/pricing/
  https://aws.amazon.com/cloudwatch/pricing/
  https://aws.amazon.com/s3/pricing/
  https://aws.amazon.com/ec2/pricing/

To minimize cost in the lab:
  - keep enable_test_workloads = false when not testing
  - use the smallest instance types
  - reduce log retention and disable S3 archival if not needed
  - destroy resources when not in use (requires explicit approval)
EOF