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

# count (not for_each) because the route table IDs are unknown until apply;
# the list length is statically known, so count is deterministic at plan time.
resource "aws_route" "workload_default_to_tgw" {
  count = length(var.workload_default_route_table_ids)

  route_table_id         = var.workload_default_route_table_ids[count.index]
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
#
# SECURITY-CRITICAL: the route table and the firewall endpoint are aligned by the
# SAME AZ-index key (e.g. "0" = AZ A, "1" = AZ B), NOT by a positional list index.
# Each.key comes from var.firewall_endpoint_ids_by_az and is looked up in
# var.inspection_tgw_route_table_ids with the identical key, so the TGW
# attachment subnet route table in AZ N always points to the firewall endpoint in
# AZ N. This eliminates the class of defects where unordered endpoint status
# lists or positional list-index coupling route traffic to the wrong-AZ firewall
# endpoint, which presents at runtime as "firewall received 0 packets" despite
# apparently correct route tables.
#
# A key mismatch between firewall_endpoint_ids_by_az and
# inspection_tgw_route_table_ids fails loudly at plan/apply time (lookup error)
# rather than silently producing a misaligned route.
resource "aws_route" "tgw_to_firewall" {
  for_each = var.firewall_routes_enabled ? var.firewall_endpoint_ids_by_az : {}

  route_table_id         = var.inspection_tgw_route_table_ids[each.key]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = each.value
}

# ----- Public subnet spoke-CIDR return routes -> same-AZ firewall endpoint -----
#
# SECURITY-CRITICAL return-path fix. After a NAT Gateway destination-translates
# a return packet to a private workload IP, that packet lands in the inspection
# public subnet route table. Without explicit spoke-CIDR routes it would match
# the public 0.0.0.0/0 -> IGW default and be dropped (private destination over
# the IGW). These routes send spoke-CIDR return traffic back through the SAME-AZ
# Network Firewall endpoint so the stateful firewall sees the return flow, then
# the firewall subnet's spoke-CIDR -> TGW route returns it to the originating
# workload via the Transit Gateway. This preserves symmetric, inspected return
# traffic and does NOT bypass the firewall (the return traverses the NFW
# endpoint, not a direct NAT->TGW path).
#
# Route table and endpoint are aligned by the SAME AZ-index key (each.key), not
# by positional list index. A key mismatch between inspection_public_route_table_ids
# and firewall_endpoint_ids_by_az fails loudly at plan/apply time (lookup error).
resource "aws_route" "public_to_firewall_spokes" {
  for_each = {
    for pair in setproduct(keys(var.inspection_public_route_table_ids), var.spoke_cidrs) :
    "${pair[0]}|${pair[1]}" => {
      az_key     = pair[0]
      spoke_cidr = pair[1]
    }
  }

  route_table_id         = var.inspection_public_route_table_ids[each.value.az_key]
  destination_cidr_block = each.value.spoke_cidr
  vpc_endpoint_id        = var.firewall_endpoint_ids_by_az[each.value.az_key]
}