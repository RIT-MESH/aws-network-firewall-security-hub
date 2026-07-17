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
