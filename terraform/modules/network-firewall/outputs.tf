output "firewall_arn" {
  description = "ARN of the AWS Network Firewall."
  value       = aws_networkfirewall_firewall.this.arn
}

output "firewall_id" {
  description = "ID of the AWS Network Firewall."
  value       = aws_networkfirewall_firewall.this.id
}

output "firewall_policy_arn" {
  description = "ARN of the attached firewall policy."
  value       = var.firewall_policy_arn
}

output "endpoint_ids" {
  description = "Network Firewall endpoint IDs ordered by az_names. Unknown until the firewall is applied."
  value = [
    for az in var.az_names :
    [for st in aws_networkfirewall_firewall.this.firewall_status[0].sync_states : st.attachment[0].endpoint_id if st.availability_zone == az][0]
  ]
}

output "logging_configuration_id" {
  description = "ID of the logging configuration, or null when no log destinations are configured."
  value       = length(aws_networkfirewall_logging_configuration.this) > 0 ? aws_networkfirewall_logging_configuration.this[0].id : null
}