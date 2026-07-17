output "transit_gateway_id" {
  description = "ID of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.arn
}

output "attachment_ids" {
  description = "Map of attachment key -> attachment ID."
  value       = { for k, a in aws_ec2_transit_gateway_vpc_attachment.this : k => a.id }
}

output "attachment_arns" {
  description = "Map of attachment key -> attachment ARN."
  value       = { for k, a in aws_ec2_transit_gateway_vpc_attachment.this : k => a.arn }
}

output "route_table_ids" {
  description = "Map of route table key -> route table ID."
  value       = { for k, rt in aws_ec2_transit_gateway_route_table.this : k => rt.id }
}