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

# Deterministic AZ-name -> endpoint-id map. The firewall_endpoint_per_az check
# block (see main.tf) asserts each AZ in az_names has exactly one endpoint, so
# the [0] indexing below is safe at apply time. Derived once and reused by both
# outputs to guarantee the list and the map stay consistent.
locals {
  endpoint_id_by_az_name = {
    for az in var.az_names :
    az => [for st in aws_networkfirewall_firewall.this.firewall_status[0].sync_states : st.attachment[0].endpoint_id if st.availability_zone == az][0]
  }
}

output "endpoint_ids_by_az" {
  description = "Map of AZ index (string, e.g. \"0\",\"1\") -> Network Firewall endpoint ID. Keys align with inspection_tgw_route_table_ids so each TGW attachment subnet route table points to the same-AZ firewall endpoint deterministically."
  value = {
    for i, az in var.az_names : tostring(i) => local.endpoint_id_by_az_name[az]
  }
}

output "endpoint_ids" {
  description = "Network Firewall endpoint IDs ordered by az_names. Unknown until the firewall is applied. Prefer endpoint_ids_by_az for per-AZ routing."
  value       = [for az in var.az_names : local.endpoint_id_by_az_name[az]]
}

output "logging_configuration_id" {
  description = "ID of the logging configuration, or null when no log destinations are configured."
  value       = length(aws_networkfirewall_logging_configuration.this) > 0 ? aws_networkfirewall_logging_configuration.this[0].id : null
}
