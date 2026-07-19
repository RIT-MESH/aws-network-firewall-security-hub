output "nat_gateway_ids" {
  description = "Map of AZ index -> NAT Gateway ID, or empty when NAT is disabled."
  value       = { for k, ngw in aws_nat_gateway.this : k => ngw.id }
}

output "nat_gateway_public_ips" {
  description = "Map of AZ index -> NAT Gateway EIP, or empty when NAT is disabled."
  value       = { for k, eip in aws_eip.nat : k => eip.public_ip }
}

output "workload_default_route_count" {
  description = "Number of workload app subnet default routes pointing to the Transit Gateway."
  value       = length(var.workload_default_route_table_ids)
}

output "firewall_endpoint_route_count" {
  description = "Number of TGW-attachment-to-firewall routes created (one per AZ key present in firewall_endpoint_ids_by_az when enabled)."
  value       = var.firewall_routes_enabled ? length(var.firewall_endpoint_ids_by_az) : 0
}

output "firewall_endpoint_route_az_keys" {
  description = "Sorted AZ-index keys for which a TGW->firewall route was created. Must equal the keys of inspection_tgw_route_table_ids."
  value       = var.firewall_routes_enabled ? sort(keys(var.firewall_endpoint_ids_by_az)) : []
}
