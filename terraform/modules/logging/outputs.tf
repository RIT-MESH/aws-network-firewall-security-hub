output "alert_log_group_name" {
  description = "CloudWatch log group name for firewall ALERT logs, or null when disabled."
  value       = var.enable_cloudwatch ? aws_cloudwatch_log_group.alert[0].name : null
}

output "flow_log_group_name" {
  description = "CloudWatch log group name for firewall FLOW logs, or null when disabled."
  value       = var.enable_cloudwatch ? aws_cloudwatch_log_group.flow[0].name : null
}

output "s3_bucket_name" {
  description = "S3 bucket name for firewall log archival, or null when disabled."
  value       = var.enable_s3_archival ? aws_s3_bucket.logs[0].id : null
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for firewall log archival, or null when disabled."
  value       = var.enable_s3_archival ? aws_s3_bucket.logs[0].arn : null
}

# A ready-to-pass list for the network-firewall module logging_destinations variable.
output "firewall_log_destinations" {
  description = "List of log destinations to pass to the network-firewall module."
  value = concat(
    var.enable_cloudwatch ? [
      { log_type = "ALERT", log_destination_type = "CloudWatchLogs", log_destination = { log_group = aws_cloudwatch_log_group.alert[0].name } },
      { log_type = "FLOW", log_destination_type = "CloudWatchLogs", log_destination = { log_group = aws_cloudwatch_log_group.flow[0].name } },
    ] : [],
    var.enable_s3_archival ? [
      { log_type = "ALERT", log_destination_type = "S3", log_destination = { bucket_name = aws_s3_bucket.logs[0].id } },
      { log_type = "FLOW", log_destination_type = "S3", log_destination = { bucket_name = aws_s3_bucket.logs[0].id } },
    ] : [],
  )
}