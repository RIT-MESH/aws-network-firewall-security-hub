output "dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.firewall.dashboard_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS alarm topic, or null when SNS is disabled."
  value       = var.enable_sns ? aws_sns_topic.alarms[0].arn : null
}

output "alert_volume_alarm_name" {
  description = "Name of the firewall alert-volume alarm (empty when alert logs disabled)."
  value       = length(aws_cloudwatch_metric_alarm.alert_volume) > 0 ? aws_cloudwatch_metric_alarm.alert_volume[0].alarm_name : ""
}

output "dropped_spikes_alarm_name" {
  description = "Name of the firewall dropped-spikes alarm."
  value       = aws_cloudwatch_metric_alarm.dropped_spikes.alarm_name
}