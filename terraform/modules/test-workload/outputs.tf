output "instance_ids" {
  description = "Map of instance key -> instance ID. Empty when disabled."
  value       = { for k, i in aws_instance.test : k => i.id }
}

output "instance_private_ips" {
  description = "Map of instance key -> private IP. Empty when disabled."
  value       = { for k, i in aws_instance.test : k => i.private_ip }
}

output "security_group_ids" {
  description = "Map of instance key -> security group ID. Empty when disabled."
  value       = { for k, sg in aws_security_group.test : k => sg.id }
}

output "ssm_role_name" {
  description = "Name of the SSM IAM role, or null when disabled."
  value       = var.enabled ? aws_iam_role.ssm[0].name : null
}

output "enabled" {
  description = "Whether test workloads are enabled."
  value       = var.enabled
}