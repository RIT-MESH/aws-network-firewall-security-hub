# Firewall logging

AWS Network Firewall sends two log types:

- **ALERT** - records for traffic that matched a stateful alert/drop/pass rule.
- **FLOW** - records for every connection the firewall inspected (passthrough
  and blocked).

This platform sends both to CloudWatch Logs (operational) and to an encrypted
S3 bucket (archival) by default. Both can be disabled independently.

## Expected log fields

### Alert log (JSON, one record per matching flow)

| Field | Description |
| --- | --- |
| `timestamp` | Event time |
| `event_type` | `alert` |
| `firewall_arn` | Firewall ARN |
| `action` | `drop`, `alert`, or `pass` |
| `rule_group` | Rule group that matched |
| `sid` | Signature ID that matched |
| `msg` | Rule message |
| `src_ip`, `src_port` | Source |
| `dest_ip`, `dest_port` | Destination |
| `protocol` | L4 protocol |
| `direction` | Flow direction |

### Flow log (JSON)

| Field | Description |
| --- | --- |
| `timestamp` | Event time |
| `event_type` | `flow` |
| `action` | `PASS` or `DROP` |
| `src_ip`, `src_port` | Source |
| `dest_ip`, `dest_port` | Destination |
| `protocol` | L4 protocol |
| `packets`, `bytes` | Volume |

> Exact field names follow the AWS Network Firewall published schema and may
> change. Confirm against deployed logs; see AWS Network Firewall documentation.

## CloudWatch destinations

- Alert log group: `/aws/network-firewall/anfw-<environment>/alert`
- Flow log group: `/aws/network-firewall/anfw-<environment>/flow`
- A CloudWatch Logs resource policy grants `networkfirewall.amazonaws.com`
  `CreateLogStream`/`DescribeLogStreams`/`PutLogEvents` on these groups.
- Retention is configurable via `firewall_log_retention_days`.

## S3 archival

- Bucket: `anfw-<environment>-firewall-logs`
- Server-side encryption (SSE-S3 AES256) enabled.
- Public access fully blocked (`block_public_acls`, `block_public_policy`,
  `ignore_public_acls`, `restrict_public_buckets`).
- Object ownership `BucketOwnerEnforced` (ACLs disabled).
- Versioning enabled; lifecycle transitions to Standard-IA, then Glacier Deep
  Archive, then expires (configurable; noncurrent versions expire after 90d).
- Bucket policy grants `delivery.logs.amazonaws.com` `s3:PutObject` on the
  `AWSLogs/*` prefix with `bucket-owner-full-control` ACL.

## Monitoring

- CloudWatch dashboard `anfw-<environment>-firewall` with dropped/passed/received
  packet metrics and log-metric widgets.
- Log metric filters: `FirewallAlertCount` (alert log group) and
  `FirewallDroppedFlowCount` (flow log group).
- Alarms: alert-volume-high and dropped-spikes. Optional SNS topic when
  `enable_monitoring_sns = true`.

## Troubleshooting

1. **No logs in CloudWatch**: confirm the CloudWatch Logs resource policy was
   created and that the firewall logging configuration references the correct
   log group names.
2. **No logs in S3**: confirm the bucket policy grants `delivery.logs.amazonaws.com`
   `s3:PutObject` and that the bucket name matches the logging configuration.
3. **Alarms never fire**: metric filters depend on log field names; verify the
   deployed log schema matches the filter patterns (`$.event_type`, `$.action`).
4. **High cost**: reduce retention, disable S3 archival, or reduce logging to FLOW
   only.
5. **Logging delivery errors**: AWS Network Firewall may emit delivery errors; a
   dedicated logging-delivery alarm requires a custom metric and is documented as
   a runtime-validation item.

## Limitations

- Log field names are assumed from public AWS documentation and require runtime
  confirmation.
- The logging-delivery alarm is not implemented because AWS does not expose a
  reliable built-in metric for it; monitor via CloudWatch Logs Insights instead.
