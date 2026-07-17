locals {
  module_tags = merge(var.tags, {
    Module = "test-workload"
  })

  active_instances = var.enabled ? var.instances : {}
}

# AMI id resolved from SSM (Amazon Linux 2023). Not fetched during static
# validation; resolved at plan/apply.
data "aws_ssm_parameter" "ami" {
  count = var.enabled ? 1 : 0
  name  = var.ami_ssm_parameter
}

# ----- IAM role for SSM access (no public SSH) -----

data "aws_iam_policy_document" "ec2_assume" {
  count = var.enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  count = var.enabled ? 1 : 0

  name               = "${var.name_prefix}-test-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume[0].json
  tags               = merge(local.module_tags, { Name = "${var.name_prefix}-test-ssm-role" })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = var.enabled ? 1 : 0

  role       = aws_iam_role.ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "test" {
  count = var.enabled ? 1 : 0

  name = "${var.name_prefix}-test-instance-profile"
  role = aws_iam_role.ssm[0].name
  tags = local.module_tags
}

# ----- Per-instance security groups (no ingress, controlled egress) -----

resource "aws_security_group" "test" {
  # checkov:skip=CKV_AWS_382:Broad egress is required so test traffic reaches the inspection firewall for validation; not used in production. Risk: broad outbound from test instances. Compensating control: test workloads are optional, private, and SSM-managed; firewall enforces egress policy. Reviewer: restrict egress in production.

  description = "Test workload security group (no ingress; broad egress for validation only)"
  for_each    = local.active_instances

  name   = "${var.name_prefix}-test-${each.value.name}"
  vpc_id = each.value.vpc_id

  # No ingress: administration is via SSM Session Manager, not public SSH/RDP.
  egress {
    description = "Outbound for SSM and test traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.module_tags, { Name = "${var.name_prefix}-test-${each.value.name}" })
}

# ----- Private test instances -----

resource "aws_instance" "test" {
  # checkov:skip=CKV_AWS_126:Detailed monitoring is not required for short-lived test instances. Risk: limited observability. Compensating control: CloudWatch firewall metrics. Reviewer: enable for production workloads.
  # checkov:skip=CKV_AWS_135:EBS-optimized attribute not set; small test instance types are EBS-optimized by default. Risk: none material. Compensating control: gp3 encrypted root volume. Reviewer: set ebs_optimized for production.
  for_each = local.active_instances

  ami           = data.aws_ssm_parameter.ami[0].value
  instance_type = var.instance_type
  subnet_id     = each.value.subnet_id

  # No public IP address.
  associate_public_ip_address = false

  vpc_security_group_ids = [aws_security_group.test[each.key].id]
  iam_instance_profile   = aws_iam_instance_profile.test[0].name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.volume_size_gb
  }

  user_data = base64gzip(<<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    # Minimal test tooling only. No network scanning tools are installed.
    dnf -y install --allowerasing curl python3 python3-pip
    systemctl enable --now amazon-ssm-agent || true
  EOT
  )

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-test-${each.value.name}"
    Role = "test-workload"
  })

  depends_on = [aws_iam_role_policy_attachment.ssm_core]
}