output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr" {
  description = "Primary CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "az_names" {
  description = "Availability Zone names used by the VPC."
  value       = var.az_names
}

output "subnet_ids" {
  description = "Map of subnet key -> subnet ID."
  value       = { for k, s in aws_subnet.this : k => s.id }
}

output "subnet_arns" {
  description = "Map of subnet key -> subnet ARN."
  value       = { for k, s in aws_subnet.this : k => s.arn }
}

output "subnet_ids_by_purpose" {
  description = "Map of subnet purpose -> list of subnet IDs."
  value = { for purpose in distinct([for k, s in var.subnets : s.purpose]) :
    purpose => [for k, s in var.subnets : aws_subnet.this[k].id if s.purpose == purpose]
  }
}

output "subnet_cidr_blocks" {
  description = "Map of subnet key -> CIDR block."
  value       = { for k, s in var.subnets : k => s.cidr }
}

output "route_table_ids" {
  description = "Map of subnet key -> route table ID."
  value       = { for k, rt in aws_route_table.this : k => rt.id }
}

output "route_table_ids_by_purpose" {
  description = "Map of subnet purpose -> list of route table IDs."
  value = { for purpose in distinct([for k, s in var.subnets : s.purpose]) :
    purpose => [for k, s in var.subnets : aws_route_table.this[k].id if s.purpose == purpose]
  }
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway, or null when not created."
  value       = length(aws_internet_gateway.this) > 0 ? aws_internet_gateway.this[0].id : null
}

output "flow_log_group_name" {
  description = "Name of the VPC flow log group, or null when flow logs are disabled."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow[0].name : null
}
