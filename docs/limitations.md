# Limitations

- Static tests prove configuration intent, not runtime behavior. Packet-level
  validation requires deploying in AWS.
- `terraform plan` of the per-AZ firewall-endpoint routes requires the firewall
  to be applied first (endpoint ids are unknown until the firewall exists).
  The configuration plans correctly because the route count is known
  (`firewall_routes_enabled` + AZ count); endpoint values resolve at apply.
- AWS Network Firewall supports Suricata-compatible rules but not full Suricata
  feature parity. Confirm rule behavior against the deployed firewall.
- Log field names in metric filters assume the published AWS schema; verify
  against deployed logs.
- A dedicated logging-delivery alarm is not implemented (no reliable built-in
  metric); monitor via CloudWatch Logs Insights.
- S3 log bucket name uses a fixed prefix and may need adjustment for global
  uniqueness in some accounts/regions.
- Pre-commit hook versions are pinned but should be refreshed periodically.