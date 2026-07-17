locals {
  module_tags = merge(var.tags, {
    Module = "vpc"
    Vpc    = var.vpc_name
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  tags                 = merge(local.module_tags, { Name = var.vpc_name })
}

resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = var.az_names[each.value.az_index]
  map_public_ip_on_launch = each.value.map_public_ip

  tags = merge(local.module_tags, {
    Name    = "${var.vpc_name}-${each.key}"
    Purpose = each.value.purpose
    AzIndex = tostring(each.value.az_index)
  })
}

# One route table per subnet so later phases can attach per-AZ routes (for
# example, per-AZ firewall endpoint routes in the inspection VPC) without
# affecting unrelated subnets.
resource "aws_route_table" "this" {
  for_each = var.subnets

  vpc_id = aws_vpc.this.id
  tags = merge(local.module_tags, {
    Name    = "${var.vpc_name}-${each.key}-rt"
    Purpose = each.value.purpose
  })
}

resource "aws_route_table_association" "this" {
  for_each = var.subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}

# Restrict the VPC default security group to all traffic. Workload security
# groups are created explicitly where needed (test-workload module).
resource "aws_default_security_group" "this" {
  # checkov:skip=CKV_AWS_23:aws_default_security_group description is provider-managed and cannot be configured; the group is restricted to no rules.
  # Restrict the VPC default security group to no ingress/egress rules. Workload
  # security groups are created explicitly where needed (test-workload module).
  vpc_id = aws_vpc.this.id
  tags   = merge(local.module_tags, { Name = "${var.vpc_name}-default-sg" })
}
resource "aws_internet_gateway" "this" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id
  tags   = merge(local.module_tags, { Name = "${var.vpc_name}-igw" })
}

# Default route to the IGW for public subnets (purpose == "public"). Subnets do
# not map public IPs; NAT Gateways (created by the inspection-routing module) get
# their EIPs directly.
resource "aws_route" "public_internet" {
  for_each = { for k, s in var.subnets : k => s if s.purpose == "public" }

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

# Optional VPC flow logs to CloudWatch Logs.
resource "aws_cloudwatch_log_group" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  # checkov:skip=CKV_AWS_158:VPC flow log group KMS encryption not configured for this lab; SSE via CloudWatch default is acceptable. Reviewer: enable CMK for production.
  # checkov:skip=CKV_AWS_338:Retention is configurable (flow_log_retention_days) and intentionally short for lab cost. Reviewer: set >=365 for production.
  name              = "/aws/vpc/${var.vpc_name}/flow"
  retention_in_days = var.flow_log_retention_days
  tags              = local.module_tags
}

data "aws_iam_policy_document" "flow_assume" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name               = "${var.vpc_name}-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_assume[0].json
  tags               = local.module_tags
}

data "aws_iam_policy_document" "flow_perms" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/vpc/${var.vpc_name}/flow:*"]
  }
}

resource "aws_iam_policy" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "${var.vpc_name}-flow-log-policy"
  policy = data.aws_iam_policy_document.flow_perms[0].json
  tags   = local.module_tags
}

resource "aws_iam_role_policy_attachment" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  role       = aws_iam_role.flow[0].name
  policy_arn = aws_iam_policy.flow[0].arn
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow[0].arn
  iam_role_arn         = aws_iam_role.flow[0].arn
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  tags                 = local.module_tags
}
