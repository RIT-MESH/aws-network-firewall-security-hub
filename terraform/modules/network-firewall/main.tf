locals {
  module_tags = merge(var.tags, {
    Module = "network-firewall"
  })
}

resource "aws_networkfirewall_firewall" "this" {
  name                              = var.name
  description                       = var.description
  vpc_id                            = var.vpc_id
  firewall_policy_arn               = var.firewall_policy_arn
  delete_protection                 = var.delete_protection
  subnet_change_protection          = var.subnet_change_protection
  firewall_policy_change_protection = var.firewall_policy_change_protection

  dynamic "subnet_mapping" {
    for_each = toset(var.subnet_ids)

    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = merge(local.module_tags, { Name = var.name })
}

resource "aws_networkfirewall_logging_configuration" "this" {
  count = length(var.logging_destinations) > 0 ? 1 : 0

  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    dynamic "log_destination_config" {
      for_each = { for i, d in var.logging_destinations : "${d.log_type}|${d.log_destination_type}|${i}" => d }

      content {
        log_type             = log_destination_config.value.log_type
        log_destination_type = log_destination_config.value.log_destination_type
        log_destination      = log_destination_config.value.log_destination
      }
    }
  }
}