# Foundational outputs. Resource-specific outputs (VPC IDs, subnet IDs, Transit
# Gateway ID, firewall ARNs, log group names, S3 bucket name, etc.) are added in
# later phases as the corresponding modules are implemented.

output "project_name" {
  description = "Project name applied to all resources via tags."
  value       = local.project_name
}

output "environment" {
  description = "Deployment environment used in naming and tags."
  value       = var.environment
}

output "name_prefix" {
  description = "Common resource name prefix: anfw-<environment>."
  value       = local.name_prefix
}

output "common_tags" {
  description = "Common tag set applied to all taggable resources."
  value       = local.common_tags
}
