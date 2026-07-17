# Central composition root for the AWS Network Firewall Security Hub.
#
# Dependency order:
#   1. VPCs (inspection, production, development, shared services)  [Phase 2]
#   2. Transit Gateway and VPC attachments                         [Phase 3]
#   3. Inspection routing (security-critical)                      [Phase 3]
#   4. AWS Network Firewall and firewall policy                    [Phase 4]
#   5. Logging and monitoring                                       [Phase 5]
#   6. Optional test workloads                                      [Phase 6]

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
      appliance_mode = true # required for symmetric inspection routing
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
    # Production + Development share the workload route table.
    # Default route forces all egress/cross-VPC traffic to the inspection VPC.
    workload = {
      associations = ["production", "development"]
      propagations = []
      routes = [
        { destination = "0.0.0.0/0", target_attachment = "inspection" },
      ]
      blackhole_routes = []
    }

    # Shared Services has its own routing domain but still defaults to inspection.
    shared_services = {
      associations = ["shared_services"]
      propagations = []
      routes = [
        { destination = "0.0.0.0/0", target_attachment = "inspection" },
      ]
      blackhole_routes = []
    }

    # Inspection route table: spoke CIDRs propagate here so the inspection VPC
    # knows how to return cross-VPC traffic to the correct spoke via the TGW.
    inspection = {
      associations     = ["inspection"]
      propagations     = ["production", "development", "shared_services"]
      routes           = []
      blackhole_routes = []
    }
  }
}

# ----- 3. Inspection routing (NAT + centralized route entries) -----

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

  # Wired up in Phase 4 once the firewall endpoints exist.
  firewall_endpoints = {}
}