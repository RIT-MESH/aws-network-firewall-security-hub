# Cost considerations

This architecture may incur AWS charges. No fixed prices are published here;
review current AWS pricing before deploying.

## Cost-relevant components

- AWS Network Firewall: per-endpoint hourly + per-GB processing (2 endpoints for HA).
- Transit Gateway: per-attachment hourly + per-GB data processing (4 attachments).
- NAT Gateways: per-endpoint hourly + per-GB (2 for HA).
- CloudWatch Logs: ingestion + retention (alert + flow + optional VPC flow logs).
- S3: storage + lifecycle transitions for log archival.
- EC2 test instances: only when `enable_test_workloads = true`.
- Cross-AZ data transfer.

## Minimize cost in the lab

- Keep `enable_test_workloads = false` when not testing.
- Use the smallest instance types.
- Reduce `firewall_log_retention_days`; disable S3 archival if not needed.
- Destroy resources when idle (explicit approval required).

## References

- <https://aws.amazon.com/network-firewall/pricing/>
- <https://aws.amazon.com/vpc/pricing/>
- <https://aws.amazon.com/cloudwatch/pricing/>
- <https://aws.amazon.com/s3/pricing/>
- <https://aws.amazon.com/ec2/pricing/>
