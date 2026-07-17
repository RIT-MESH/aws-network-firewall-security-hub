output "endpoint_ids" {
  description = "Map of SSM service name -> VPC endpoint ID."
  value       = { for k, e in aws_vpc_endpoint.ssm : k => e.id }
}

output "security_group_id" {
  description = "ID of the endpoint security group."
  value       = aws_security_group.endpoints.id
}
