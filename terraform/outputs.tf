# Foundational + VPC outputs. Additional outputs (Transit Gateway, firewall,
# logging, S3, test instances) are added in later phases.

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

output "az_names" {
  description = "Availability Zone names used across VPCs."
  value       = local.az_names
}

output "vpc_ids" {
  description = "Map of VPC name -> VPC ID."
  value = {
    inspection      = module.inspection_vpc.vpc_id
    production      = module.production_vpc.vpc_id
    development     = module.development_vpc.vpc_id
    shared_services = module.shared_services_vpc.vpc_id
  }
}

output "vpc_cidr_blocks" {
  description = "Map of VPC name -> CIDR block."
  value = {
    inspection      = module.inspection_vpc.vpc_cidr
    production      = module.production_vpc.vpc_cidr
    development     = module.development_vpc.vpc_cidr
    shared_services = module.shared_services_vpc.vpc_cidr
  }
}

output "subnet_ids_by_purpose" {
  description = "Map of VPC name -> (purpose -> list of subnet IDs)."
  value = {
    inspection      = module.inspection_vpc.subnet_ids_by_purpose
    production      = module.production_vpc.subnet_ids_by_purpose
    development     = module.development_vpc.subnet_ids_by_purpose
    shared_services = module.shared_services_vpc.subnet_ids_by_purpose
  }
}

output "route_table_ids_by_purpose" {
  description = "Map of VPC name -> (purpose -> list of route table IDs)."
  value = {
    inspection      = module.inspection_vpc.route_table_ids_by_purpose
    production      = module.production_vpc.route_table_ids_by_purpose
    development     = module.development_vpc.route_table_ids_by_purpose
    shared_services = module.shared_services_vpc.route_table_ids_by_purpose
  }
}

output "inspection_internet_gateway_id" {
  description = "ID of the inspection VPC Internet Gateway (workload VPCs intentionally have none)."
  value       = module.inspection_vpc.internet_gateway_id
}

output "vpc_flow_log_group_names" {
  description = "Map of VPC name -> flow log group name, or null when flow logs are disabled."
  value = {
    inspection      = module.inspection_vpc.flow_log_group_name
    production      = module.production_vpc.flow_log_group_name
    development     = module.development_vpc.flow_log_group_name
    shared_services = module.shared_services_vpc.flow_log_group_name
  }
}

# ----- Transit Gateway outputs -----

output "transit_gateway_id" {
  description = "ID of the centralized Transit Gateway."
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "ARN of the centralized Transit Gateway."
  value       = module.transit_gateway.transit_gateway_arn
}

output "transit_gateway_attachment_ids" {
  description = "Map of attachment key -> VPC attachment ID."
  value       = module.transit_gateway.attachment_ids
}

output "transit_gateway_route_table_ids" {
  description = "Map of route table key -> Transit Gateway route table ID."
  value       = module.transit_gateway.route_table_ids
}

# ----- Inspection routing outputs -----

output "inspection_nat_gateway_ids" {
  description = "Map of AZ index -> NAT Gateway ID in the inspection VPC."
  value       = module.inspection_routing.nat_gateway_ids
}

output "inspection_nat_gateway_public_ips" {
  description = "Map of AZ index -> NAT Gateway public IP in the inspection VPC."
  value       = module.inspection_routing.nat_gateway_public_ips
  sensitive   = false
}
# ----- Firewall outputs -----

output "firewall_arn" {
  description = "ARN of the centralized AWS Network Firewall."
  value       = module.network_firewall.firewall_arn
}

output "firewall_id" {
  description = "ID of the centralized AWS Network Firewall."
  value       = module.network_firewall.firewall_id
}

output "firewall_policy_arn" {
  description = "ARN of the firewall policy attached to the firewall."
  value       = module.network_firewall.firewall_policy_arn
}

output "firewall_policy_id" {
  description = "ID of the firewall policy."
  value       = module.firewall_policy.firewall_policy_id
}

output "firewall_endpoint_ids" {
  description = "Network Firewall endpoint IDs ordered by AZ. Unknown until the firewall is applied."
  value       = module.network_firewall.endpoint_ids
}

output "stateful_rule_group_arns" {
  description = "Map of stateful rule group name -> ARN."
  value       = module.firewall_policy.stateful_rule_group_arns
}
# ----- Logging outputs -----

output "firewall_alert_log_group_name" {
  description = "CloudWatch log group for firewall ALERT logs, or null when disabled."
  value       = module.logging.alert_log_group_name
}

output "firewall_flow_log_group_name" {
  description = "CloudWatch log group for firewall FLOW logs, or null when disabled."
  value       = module.logging.flow_log_group_name
}

output "firewall_log_bucket_name" {
  description = "S3 bucket name for firewall log archival, or null when disabled."
  value       = module.logging.s3_bucket_name
}

output "firewall_log_bucket_arn" {
  description = "S3 bucket ARN for firewall log archival, or null when disabled."
  value       = module.logging.s3_bucket_arn
}

# ----- Monitoring outputs -----

output "firewall_dashboard_name" {
  description = "Name of the CloudWatch firewall dashboard."
  value       = module.monitoring.dashboard_name
}

output "firewall_alarm_sns_topic_arn" {
  description = "ARN of the SNS alarm topic, or null when SNS is disabled."
  value       = module.monitoring.sns_topic_arn
}
# ----- Test workload outputs -----

output "test_instance_ids" {
  description = "Map of test instance key -> instance ID. Empty when test workloads are disabled."
  value       = module.test_workloads.instance_ids
}

output "test_instance_private_ips" {
  description = "Map of test instance key -> private IP. Empty when test workloads are disabled."
  value       = module.test_workloads.instance_private_ips
}

output "test_workloads_enabled" {
  description = "Whether test workloads are enabled."
  value       = module.test_workloads.enabled
}

# ----- SSM VPC endpoint outputs -----

output "ssm_endpoint_ids" {
  description = "Map of workload VPC -> (SSM service -> endpoint ID). Endpoint IDs are account-specific; do not publish in public docs."
  value = {
    production      = module.ssm_endpoints_production.endpoint_ids
    development     = module.ssm_endpoints_development.endpoint_ids
    shared_services = module.ssm_endpoints_shared_services.endpoint_ids
  }
}

output "ssm_endpoint_security_group_ids" {
  description = "Map of workload VPC -> endpoint security group ID."
  value = {
    production      = module.ssm_endpoints_production.security_group_id
    development     = module.ssm_endpoints_development.security_group_id
    shared_services = module.ssm_endpoints_shared_services.security_group_id
  }
}