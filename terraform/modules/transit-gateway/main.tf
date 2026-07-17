locals {
  module_tags = merge(var.tags, {
    Module = "transit-gateway"
  })

  # Flatten nested association/propagation/route definitions into keyed sets so
  # for_each can create one resource per entry with a stable key.
  associations = flatten([
    for rt_key, rt in var.route_tables : [
      for att in rt.associations : {
        key            = "${rt_key}|${att}"
        rt_key         = rt_key
        attachment_key = att
      }
    ]
  ])

  propagations = flatten([
    for rt_key, rt in var.route_tables : [
      for att in rt.propagations : {
        key            = "${rt_key}|${att}"
        rt_key         = rt_key
        attachment_key = att
      }
    ]
  ])

  routes = flatten([
    for rt_key, rt in var.route_tables : [
      for r in rt.routes : {
        key               = "${rt_key}|${r.destination}|${r.target_attachment}"
        rt_key            = rt_key
        destination       = r.destination
        target_attachment = r.target_attachment
      }
    ]
  ])

  blackhole_routes = flatten([
    for rt_key, rt in var.route_tables : [
      for cidr in rt.blackhole_routes : {
        key         = "${rt_key}|${cidr}"
        rt_key      = rt_key
        destination = cidr
      }
    ]
  ])
}

resource "aws_ec2_transit_gateway" "this" {
  description                     = var.description
  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments
  default_route_table_association = var.default_route_table_association
  default_route_table_propagation = var.default_route_table_propagation
  dns_support                     = var.dns_support
  vpn_ecmp_support                = var.vpn_ecmp_support

  tags = merge(local.module_tags, { Name = var.name })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.attachments

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  appliance_mode_support = each.value.appliance_mode ? "enable" : "disable"
  dns_support            = "enable"

  tags = merge(local.module_tags, { Name = "${var.name}-${each.key}-attach" })
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = var.route_tables

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = merge(local.module_tags, { Name = "${var.name}-${each.key}-rt" })
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = { for x in local.associations : x.key => x }

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.rt_key].id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.value.attachment_key].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = { for x in local.propagations : x.key => x }

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.rt_key].id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.value.attachment_key].id
}

resource "aws_ec2_transit_gateway_route" "this" {
  for_each = { for x in local.routes : x.key => x }

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.rt_key].id
  destination_cidr_block         = each.value.destination
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.value.target_attachment].id
}

resource "aws_ec2_transit_gateway_route" "blackhole" {
  for_each = { for x in local.blackhole_routes : x.key => x }

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.rt_key].id
  destination_cidr_block         = each.value.destination
  blackhole                      = true
}