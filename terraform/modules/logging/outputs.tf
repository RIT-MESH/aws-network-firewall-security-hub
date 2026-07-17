output "alert_log_group_name" {
  description = "CloudWatch log group name for firewall ALERT logs, or null when ALERT is routed to S3 or disabled."
  value       = local.alert_to_cw ? aws_cloudwatch_log_group.alert[0].name : null
}

output "flow_log_group_name" {
  description = "CloudWatch log group name for firewall FLOW logs, or null when FLOW is routed to S3 or disabled."
  value       = local.flow_to_cw ? aws_cloudwatch_log_group.flow[0].name : null
}

output "s3_bucket_name" {
  description = "S3 bucket name for firewall log archival."
  value       = aws_s3_bucket.logs.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for firewall log archival."
  value       = aws_s3_bucket.logs.arn
}

# AWS Network Firewall: each log_type goes to ONE destination (max 2 blocks).
# Both enabled  -> ALERT->CloudWatch, FLOW->S3
# CloudWatch only -> ALERT->CloudWatch, FLOW->CloudWatch
# S3 only       -> ALERT->S3, FLOW->S3
output "firewall_log_destinations" {
  description = "List of log destinations to pass to the network-firewall module (max 2, unique log_type)."
  value = concat(
    local.alert_to_cw
    ? [{ log_type = "ALERT", log_destination_type = "CloudWatchLogs", log_destination = { log_group = aws_cloudwatch_log_group.alert[0].name } }]
    : (local.alert_to_s3 ? [{ log_type = "ALERT", log_destination_type = "S3", log_destination = { bucket_name = aws_s3_bucket.logs.id } }] : []),
    local.flow_to_cw
    ? [{ log_type = "FLOW", log_destination_type = "CloudWatchLogs", log_destination = { log_group = aws_cloudwatch_log_group.flow[0].name } }]
    : (local.flow_to_s3 ? [{ log_type = "FLOW", log_destination_type = "S3", log_destination = { bucket_name = aws_s3_bucket.logs.id } }] : []),
  )
}
