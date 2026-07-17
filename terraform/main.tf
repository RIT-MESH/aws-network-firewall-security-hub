# Central composition root for the AWS Network Firewall Security Hub.
#
# Dependency order:
#   1. VPCs (inspection, production, development, shared services)  [Phase 2]
#   2. Transit Gateway and VPC attachments                         [Phase 3]
#   3. Firewall policy + rule groups                                [Phase 4]
#   4. AWS Network Firewall                                         [Phase 4]
#   5. Inspection routing (NAT + centralized route entries)         [Phase 3/4]
#   6. Logging and monitoring                                       [Phase 5]
#   7. Optional test workloads                                      [Phase 6]

data "aws_availability_zones" "available" {
  state = "available"
}

# ----- 1. VPCs -----

module "inspection_vpc" {
  source = "./modules/vpc"

  vpc_name                = "${local.name_prefix}-inspection-vpc"
  vpc_cidr                = var.inspection_vpc_cidr
  az_names                = local.az_names
  subnets                 = local.inspection_subnets
  create_internet_gateway = true
  enable_flow_logs        = var.vpc_flow_logs_enabled
  flow_log_retention_days = var.vpc_flow_log_retention_days
  tags                    = local.merged_tags
}

module "production_vpc" {
  source = "./modules/vpc"

  vpc_name                = "${local.name_prefix}-production-vpc"
  vpc_cidr                = var.production_vpc_cidr
  az_names                = local.az_names
  subnets                 = local.production_subnets
  create_internet_gateway = false
  enable_flow_logs        = var.vpc_flow_logs_enabled
  flow_log_retention_days = var.vpc_flow_log_retention_days
  tags                    = local.merged_tags
}

module "development_vpc" {
  source = "./modules/vpc"

  vpc_name                = "${local.name_prefix}-development-vpc"
  vpc_cidr                = var.development_vpc_cidr
  az_names                = local.az_names
  subnets                 = local.development_subnets
  create_internet_gateway = false
  enable_flow_logs        = var.vpc_flow_logs_enabled
  flow_log_retention_days = var.vpc_flow_log_retention_days
  tags                    = local.merged_tags
}

module "shared_services_vpc" {
  source = "./modules/vpc"

  vpc_name                = "${local.name_prefix}-shared-services-vpc"
  vpc_cidr                = var.shared_services_vpc_cidr
  az_names                = local.az_names
  subnets                 = local.shared_services_subnets
  create_internet_gateway = false
  enable_flow_logs        = var.vpc_flow_logs_enabled
  flow_log_retention_days = var.vpc_flow_log_retention_days
  tags                    = local.merged_tags
}

# ----- 2. Transit Gateway and VPC attachments -----

module "transit_gateway" {
  source = "./modules/transit-gateway"

  name        = "${local.name_prefix}-tgw"
  description = "Centralized inspection Transit Gateway for ${var.environment}"
  tags        = local.merged_tags

  attachments = {
    inspection = {
      vpc_id         = module.inspection_vpc.vpc_id
      subnet_ids     = module.inspection_vpc.subnet_ids_by_purpose["tgw"]
      appliance_mode = true
    }
    production = {
      vpc_id         = module.production_vpc.vpc_id
      subnet_ids     = module.production_vpc.subnet_ids_by_purpose["tgw"]
      appliance_mode = false
    }
    development = {
      vpc_id         = module.development_vpc.vpc_id
      subnet_ids     = module.development_vpc.subnet_ids_by_purpose["tgw"]
      appliance_mode = false
    }
    shared_services = {
      vpc_id         = module.shared_services_vpc.vpc_id
      subnet_ids     = module.shared_services_vpc.subnet_ids_by_purpose["tgw"]
      appliance_mode = false
    }
  }

  route_tables = {
    workload = {
      associations = ["production", "development"]
      propagations = []
      routes = [
        { destination = "0.0.0.0/0", target_attachment = "inspection" },
      ]
      blackhole_routes = []
    }

    shared_services = {
      associations = ["shared_services"]
      propagations = []
      routes = [
        { destination = "0.0.0.0/0", target_attachment = "inspection" },
      ]
      blackhole_routes = []
    }

    inspection = {
      associations     = ["inspection"]
      propagations     = ["production", "development", "shared_services"]
      routes           = []
      blackhole_routes = []
    }
  }
}

# ----- 3. Firewall policy and rule groups -----

module "firewall_policy" {
  source = "./modules/firewall-policy"

  name                       = "${local.name_prefix}-firewall-policy"
  description                = "Centralized AWS Network Firewall policy for ${var.environment}"
  tags                       = local.merged_tags
  stateful_rule_order        = var.stateful_rule_order
  rule_variables             = local.rule_variables
  stateful_rule_groups       = local.stateful_rule_groups
  allowed_domains            = local.allowed_domains
  blocked_domains            = local.blocked_domains
  domain_rule_group_capacity = var.domain_rule_group_capacity
  blocked_destinations       = local.blocked_destinations
}

# ----- 4. AWS Network Firewall -----

module "network_firewall" {
  source = "./modules/network-firewall"

  name                              = "${local.name_prefix}-firewall"
  description                       = "Centralized AWS Network Firewall for ${var.environment}"
  vpc_id                            = module.inspection_vpc.vpc_id
  subnet_ids                        = local.inspection_firewall_subnet_ids
  az_names                          = local.az_names
  firewall_policy_arn               = module.firewall_policy.firewall_policy_arn
  delete_protection                 = var.firewall_delete_protection
  subnet_change_protection          = var.firewall_subnet_change_protection
  firewall_policy_change_protection = var.firewall_policy_change_protection
  tags                              = local.merged_tags

  # Log destinations are wired in Phase 5.
  logging_destinations = []
}

# ----- 5. Inspection routing (NAT + centralized route entries) -----

module "inspection_routing" {
  source = "./modules/inspection-routing"

  name_prefix = local.name_prefix
  tags        = local.merged_tags
  nat_enabled = true

  inspection_public_subnet_ids = {
    "0" = module.inspection_vpc.subnet_ids["public-a"]
    "1" = module.inspection_vpc.subnet_ids["public-b"]
  }

  inspection_firewall_route_table_ids = {
    "0" = module.inspection_vpc.route_table_ids["fw-a"]
    "1" = module.inspection_vpc.route_table_ids["fw-b"]
  }

  inspection_tgw_route_table_ids = {
    "0" = module.inspection_vpc.route_table_ids["tgw-a"]
    "1" = module.inspection_vpc.route_table_ids["tgw-b"]
  }

  transit_gateway_id = module.transit_gateway.transit_gateway_id

  spoke_cidrs = local.spoke_cidrs

  workload_default_route_table_ids = local.workload_default_route_table_ids

  # Phase 4: wire the per-AZ firewall endpoint default routes.
  firewall_routes_enabled = true
  firewall_endpoint_ids   = module.network_firewall.endpoint_ids
}