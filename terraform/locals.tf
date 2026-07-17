# Shared locals: common tags, naming prefix, Availability Zone selection, and
# the subnet maps for each VPC. Subnet CIDRs are derived from each VPC CIDR with
# cidrsubnet(prefix, 8, n) so that changing a VPC CIDR cascades to its subnets.

locals {
  project_name = "aws-network-firewall-security-hub"
  name_prefix  = "anfw-${var.environment}"

  common_tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    Purpose     = "CloudNetworkSecurityLab"
  }

  merged_tags = merge(local.common_tags, var.additional_tags)

  # Select the first N available AZs for high availability.
  az_names = slice(
    data.aws_availability_zones.available.names,
    0,
    var.availability_zone_count,
  )

  # Inspection VPC: firewall, Transit Gateway, and public/NAT subnets per AZ.
  inspection_subnets = {
    fw-a     = { cidr = cidrsubnet(var.inspection_vpc_cidr, 8, 1), az_index = 0, purpose = "firewall", map_public_ip = false }
    fw-b     = { cidr = cidrsubnet(var.inspection_vpc_cidr, 8, 2), az_index = 1, purpose = "firewall", map_public_ip = false }
    tgw-a    = { cidr = cidrsubnet(var.inspection_vpc_cidr, 8, 3), az_index = 0, purpose = "tgw", map_public_ip = false }
    tgw-b    = { cidr = cidrsubnet(var.inspection_vpc_cidr, 8, 4), az_index = 1, purpose = "tgw", map_public_ip = false }
    public-a = { cidr = cidrsubnet(var.inspection_vpc_cidr, 8, 5), az_index = 0, purpose = "public", map_public_ip = false }
    public-b = { cidr = cidrsubnet(var.inspection_vpc_cidr, 8, 6), az_index = 1, purpose = "public", map_public_ip = false }
  }

  # Production VPC: private application subnets and TGW attachment subnets.
  production_subnets = {
    app-a = { cidr = cidrsubnet(var.production_vpc_cidr, 8, 1), az_index = 0, purpose = "app", map_public_ip = false }
    app-b = { cidr = cidrsubnet(var.production_vpc_cidr, 8, 2), az_index = 1, purpose = "app", map_public_ip = false }
    tgw-a = { cidr = cidrsubnet(var.production_vpc_cidr, 8, 3), az_index = 0, purpose = "tgw", map_public_ip = false }
    tgw-b = { cidr = cidrsubnet(var.production_vpc_cidr, 8, 4), az_index = 1, purpose = "tgw", map_public_ip = false }
  }

  # Development VPC: private application subnets and TGW attachment subnets.
  development_subnets = {
    app-a = { cidr = cidrsubnet(var.development_vpc_cidr, 8, 1), az_index = 0, purpose = "app", map_public_ip = false }
    app-b = { cidr = cidrsubnet(var.development_vpc_cidr, 8, 2), az_index = 1, purpose = "app", map_public_ip = false }
    tgw-a = { cidr = cidrsubnet(var.development_vpc_cidr, 8, 3), az_index = 0, purpose = "tgw", map_public_ip = false }
    tgw-b = { cidr = cidrsubnet(var.development_vpc_cidr, 8, 4), az_index = 1, purpose = "tgw", map_public_ip = false }
  }

  # Shared Services VPC: private shared-services subnets and TGW attachment subnets.
  shared_services_subnets = {
    shared-a = { cidr = cidrsubnet(var.shared_services_vpc_cidr, 8, 1), az_index = 0, purpose = "shared", map_public_ip = false }
    shared-b = { cidr = cidrsubnet(var.shared_services_vpc_cidr, 8, 2), az_index = 1, purpose = "shared", map_public_ip = false }
    tgw-a    = { cidr = cidrsubnet(var.shared_services_vpc_cidr, 8, 3), az_index = 0, purpose = "tgw", map_public_ip = false }
    tgw-b    = { cidr = cidrsubnet(var.shared_services_vpc_cidr, 8, 4), az_index = 1, purpose = "tgw", map_public_ip = false }
  }

  # ----- Phase 3 routing helpers -----

  # Spoke VPC CIDRs that the firewall must route back to the Transit Gateway for
  # cross-VPC traffic after inspection.
  spoke_cidrs = [
    var.production_vpc_cidr,
    var.development_vpc_cidr,
    var.shared_services_vpc_cidr,
  ]

  # App/private subnet route tables in workload VPCs that default to the TGW.
  workload_default_route_table_ids = concat(
    module.production_vpc.route_table_ids_by_purpose["app"],
    module.development_vpc.route_table_ids_by_purpose["app"],
    module.shared_services_vpc.route_table_ids_by_purpose["shared"],
  )

  # ----- Phase 4 firewall helpers -----

  rules_dir = "${path.module}/../rules"

  allow_rules = file("${local.rules_dir}/stateful/allow.rules")
  deny_rules  = file("${local.rules_dir}/stateful/deny.rules")
  alert_rules = file("${local.rules_dir}/stateful/alert.rules")
  dns_rules   = file("${local.rules_dir}/stateful/dns.rules")

  blocked_destinations = [
    for l in split("\n", file("${local.rules_dir}/ip-sets/blocked-destinations.txt")) :
    trimspace(l) if trimspace(l) != "" && substr(trimspace(l), 0, 1) != "#"
  ]
  allowed_domains = [
    for l in split("\n", file("${local.rules_dir}/domain-lists/allowed-domains.txt")) :
    trimspace(l) if trimspace(l) != "" && substr(trimspace(l), 0, 1) != "#"
  ]
  blocked_domains = [
    for l in split("\n", file("${local.rules_dir}/domain-lists/blocked-domains.txt")) :
    trimspace(l) if trimspace(l) != "" && substr(trimspace(l), 0, 1) != "#"
  ]

  rule_variables = {
    LAB_HOME_NET      = [var.production_vpc_cidr, var.development_vpc_cidr, var.shared_services_vpc_cidr]
    LAB_DEV_NET       = [var.development_vpc_cidr]
    LAB_PROD_NET      = [var.production_vpc_cidr]
    LAB_SHARED_NET    = [var.shared_services_vpc_cidr]
    LAB_EXTERNAL_NET  = ["0.0.0.0/0"]
    LAB_BLOCKED_DESTS = local.blocked_destinations
  }

  stateful_rule_groups = {
    allow = { rules = local.allow_rules, capacity = var.stateful_rule_group_capacity }
    deny  = { rules = local.deny_rules, capacity = var.stateful_rule_group_capacity }
    alert = { rules = local.alert_rules, capacity = var.stateful_rule_group_capacity }
    dns   = { rules = local.dns_rules, capacity = var.stateful_rule_group_capacity }
  }

  inspection_firewall_subnet_ids = module.inspection_vpc.subnet_ids_by_purpose["firewall"]
}
