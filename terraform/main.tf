# Central composition root for the AWS Network Firewall Security Hub.
#
# Dependency order:
#   1. VPCs (inspection, production, development, shared services)  [Phase 2]
#   2. Transit Gateway and VPC attachments                         [Phase 3]
#   3. Inspection routing (security-critical)                       [Phase 3]
#   4. AWS Network Firewall and firewall policy                    [Phase 4]
#   5. Logging and monitoring                                       [Phase 5]
#   6. Optional test workloads                                      [Phase 6]

data "aws_availability_zones" "available" {
  state = "available"
}

# ----- VPCs -----

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
