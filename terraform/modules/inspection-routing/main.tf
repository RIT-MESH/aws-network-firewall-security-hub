locals {
  module_tags = merge(var.tags, {
    Module = "inspection-routing"
  })

  # Cross product of firewall route tables x spoke CIDRs for the per-AZ
  # "firewall -> Transit Gateway" cross-VPC return routes.
  fw_spoke_routes = flatten([
    for az_key, rt_id in var.inspection_firewall_route_table_ids : [
      for cidr in var.spoke_cidrs : {
        key   = "${az_key}|${cidr}"
        rt_id = rt_id
        cidr  = cidr
      }
    ]
  ])
}

# ----- NAT Gateways (centralized egress) -----

resource "aws_eip" "nat" {
  for_each = var.nat_enabled ? var.inspection_public_subnet_ids : {}

  domain = "vpc"
  tags   = merge(local.module_tags, { Name = "${var.name_prefix}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = var.nat_enabled ? var.inspection_public_subnet_ids : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value

  tags = merge(local.module_tags, { Name = "${var.name_prefix}-nat-${each.key}" })

  depends_on = [aws_eip.nat]
}

# ----- Workload app subnet default route -> Transit Gateway -----

resource "aws_route" "workload_default_to_tgw" {
  for_each = toset(var.workload_default_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id
}

# ----- Firewall subnet default route -> per-AZ NAT Gateway (internet egress) -----

resource "aws_route" "firewall_default_to_nat" {
  for_each = var.nat_enabled ? var.inspection_firewall_route_table_ids : {}

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

# ----- Firewall subnet spoke CIDR routes -> Transit Gateway (cross-VPC return) -----

resource "aws_route" "firewall_to_tgw_spokes" {
  for_each = { for r in local.fw_spoke_routes : r.key => r }

  route_table_id         = each.value.rt_id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = var.transit_gateway_id
}

# ----- Inspection TGW attachment subnet default route -> per-AZ firewall endpoint -----

resource "aws_route" "tgw_to_firewall" {
  for_each = var.firewall_endpoints

  route_table_id         = var.inspection_tgw_route_table_ids[each.key]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = each.value
}