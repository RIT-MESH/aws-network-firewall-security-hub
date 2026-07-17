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
  for_each = local.active_instances

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