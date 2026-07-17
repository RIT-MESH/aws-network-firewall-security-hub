locals {
  module_tags = merge(var.tags, {
    Module = "firewall-policy"
  })

  # Strict-order priorities. Lower number = evaluated first.
  #   50 blocked-domains (DENYLIST)        - drop restricted domains first
  #   60 allowed-domains (ALLOWLIST)       - enforce egress allowlist for HTTP/HTTPS
  #  100 deny (5-tuple drops)
  #  200 alert (alert-only suspicious traffic)
  #  300 dns (allow DNS to approved resolver)
  #  400 allow (mgmt SSH, prod->shared logging)
  stateful_priorities = {
    allow = 400
    deny  = 100
    alert = 200
    dns   = 300
  }

  blocked_domains_priority = 50
  allowed_domains_priority = 60

  stateful_refs = [
    for k, g in var.stateful_rule_groups : {
      key      = k
      priority = local.stateful_priorities[k]
      arn      = aws_networkfirewall_rule_group.stateful[k].arn
    }
  ]
}

# ----- Stateful Suricata rule groups (allow / deny / alert / dns) -----
#
# AWS Network Firewall resolves $VAR references in rules_string from the rule
# group's own rule_variables (not the firewall policy's policy_variables), so
# the IP-set variables are declared here for each stateful rule group.

resource "aws_networkfirewall_rule_group" "stateful" {
  for_each = var.stateful_rule_groups

  # checkov:skip=CKV_AWS_345:Rule group encryption uses AWS-managed encryption; CMK not configured for this lab. Risk: no customer key control. Compensating control: AWS-managed encryption. Reviewer: configure CMK for production.

  name     = "${var.name}-${each.key}"
  capacity = each.value.capacity
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = each.value.rules
    }

    dynamic "rule_variables" {
      for_each = length(var.rule_variables) > 0 ? [1] : []

      content {
        dynamic "ip_sets" {
          for_each = var.rule_variables

          content {
            key = ip_sets.key

            ip_set {
              definition = ip_sets.value
            }
          }
        }
      }
    }

    stateful_rule_options {
      rule_order = var.stateful_rule_order
    }
  }

  tags = merge(local.module_tags, { Name = "${var.name}-${each.key}" })
}

# ----- Domain-list rule groups -----

resource "aws_networkfirewall_rule_group" "allowed_domains" {
  count = length(var.allowed_domains) > 0 ? 1 : 0

  # checkov:skip=CKV_AWS_345:Rule group encryption uses AWS-managed encryption; CMK not configured for this lab. Risk: no customer key control. Compensating control: AWS-managed encryption. Reviewer: configure CMK for production.

  name     = "${var.name}-allowed-domains"
  capacity = var.domain_rule_group_capacity
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["TLS_SNI", "HTTP_HOST"]
        targets              = var.allowed_domains
      }
    }

    stateful_rule_options {
      rule_order = var.stateful_rule_order
    }
  }

  tags = merge(local.module_tags, { Name = "${var.name}-allowed-domains" })
}

resource "aws_networkfirewall_rule_group" "blocked_domains" {
  count = length(var.blocked_domains) > 0 ? 1 : 0

  # checkov:skip=CKV_AWS_345:Rule group encryption uses AWS-managed encryption; CMK not configured for this lab. Risk: no customer key control. Compensating control: AWS-managed encryption. Reviewer: configure CMK for production.

  name     = "${var.name}-blocked-domains"
  capacity = var.domain_rule_group_capacity
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["TLS_SNI", "HTTP_HOST"]
        targets              = var.blocked_domains
      }
    }

    stateful_rule_options {
      rule_order = var.stateful_rule_order
    }
  }

  tags = merge(local.module_tags, { Name = "${var.name}-blocked-domains" })
}

# ----- Stateless drop rule group for blocked destination CIDRs -----

resource "aws_networkfirewall_rule_group" "stateless_drop" {
  count = length(var.blocked_destinations) > 0 ? 1 : 0

  # checkov:skip=CKV_AWS_345:Rule group encryption uses AWS-managed encryption; CMK not configured for this lab. Risk: no customer key control. Compensating control: AWS-managed encryption. Reviewer: configure CMK for production.

  name     = "${var.name}-stateless-drop"
  capacity = var.stateless_rule_group_capacity
  type     = "STATELESS"

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        dynamic "stateless_rule" {
          for_each = { for i, c in var.blocked_destinations : c => i }

          content {
            priority = 10 + stateless_rule.value

            rule_definition {
              actions = ["aws:drop"]

              match_attributes {
                destination {
                  address_definition = stateless_rule.key
                }
              }
            }
          }
        }
      }
    }
  }

  tags = merge(local.module_tags, { Name = "${var.name}-stateless-drop" })
}

# ----- Firewall policy -----

resource "aws_networkfirewall_firewall_policy" "this" {
  # checkov:skip=CKV_AWS_346:Firewall policy encryption configuration uses AWS-managed encryption; CMK not configured for this lab. Risk: no customer key control. Compensating control: AWS-managed encryption. Reviewer: configure CMK for production.

  name        = var.name
  description = var.description
  tags        = merge(local.module_tags, { Name = var.name })

  firewall_policy {
    stateless_default_actions          = var.stateless_default_actions
    stateless_fragment_default_actions = var.stateless_fragment_default_actions
    stateful_default_actions           = var.stateful_default_actions

    stateful_engine_options {
      rule_order = var.stateful_rule_order
    }

    # 5-tuple stateful groups (allow/deny/alert/dns)
    dynamic "stateful_rule_group_reference" {
      for_each = { for r in local.stateful_refs : r.key => r }

      content {
        priority     = stateful_rule_group_reference.value.priority
        resource_arn = stateful_rule_group_reference.value.arn
      }
    }

    # blocked-domains (DENYLIST), priority 50
    dynamic "stateful_rule_group_reference" {
      for_each = length(var.blocked_domains) > 0 ? { blocked_domains = aws_networkfirewall_rule_group.blocked_domains[0].arn } : {}

      content {
        priority     = local.blocked_domains_priority
        resource_arn = stateful_rule_group_reference.value
      }
    }

    # allowed-domains (ALLOWLIST), priority 60
    dynamic "stateful_rule_group_reference" {
      for_each = length(var.allowed_domains) > 0 ? { allowed_domains = aws_networkfirewall_rule_group.allowed_domains[0].arn } : {}

      content {
        priority     = local.allowed_domains_priority
        resource_arn = stateful_rule_group_reference.value
      }
    }

    # stateless drop group, priority 1
    dynamic "stateless_rule_group_reference" {
      for_each = length(var.blocked_destinations) > 0 ? { drop = aws_networkfirewall_rule_group.stateless_drop[0].arn } : {}

      content {
        priority     = 1
        resource_arn = stateless_rule_group_reference.value
      }
    }
  }
}
