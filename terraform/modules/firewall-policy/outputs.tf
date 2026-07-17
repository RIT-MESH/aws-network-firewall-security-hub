output "firewall_policy_arn" {
  description = "ARN of the AWS Network Firewall policy."
  value       = aws_networkfirewall_firewall_policy.this.arn
}

output "firewall_policy_id" {
  description = "ID of the AWS Network Firewall policy."
  value       = aws_networkfirewall_firewall_policy.this.id
}

output "stateful_rule_group_arns" {
  description = "Map of stateful rule group name -> ARN."
  value       = { for k, g in aws_networkfirewall_rule_group.stateful : k => g.arn }
}

output "allowed_domains_rule_group_arn" {
  description = "ARN of the allowed-domains rule group, or null when none."
  value       = length(aws_networkfirewall_rule_group.allowed_domains) > 0 ? aws_networkfirewall_rule_group.allowed_domains[0].arn : null
}

output "blocked_domains_rule_group_arn" {
  description = "ARN of the blocked-domains rule group, or null when none."
  value       = length(aws_networkfirewall_rule_group.blocked_domains) > 0 ? aws_networkfirewall_rule_group.blocked_domains[0].arn : null
}

output "stateless_drop_rule_group_arn" {
  description = "ARN of the stateless drop rule group, or null when none."
  value       = length(aws_networkfirewall_rule_group.stateless_drop) > 0 ? aws_networkfirewall_rule_group.stateless_drop[0].arn : null
}