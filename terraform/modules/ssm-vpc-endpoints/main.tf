locals {
  module_tags = merge(var.tags, {
    Module = "ssm-vpc-endpoints"
  })

  services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-ssm-endpoints"
  vpc_id      = var.vpc_id
  description = "SSM PrivateLink endpoint SG: TCP 443 from the VPC CIDR only."

  ingress {
    description = "TLS 443 from the workload VPC for SSM PrivateLink"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.module_tags, { Name = "${var.name_prefix}-ssm-endpoints-sg" })
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(local.services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(local.module_tags, { Name = "${var.name_prefix}-${each.key}-endpoint" })
}
