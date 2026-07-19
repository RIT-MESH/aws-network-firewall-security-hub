locals {
  module_tags = merge(var.tags, {
    Module = "firewall-policy"
  })

  # Strict-order priorities. Lower number = evaluated first.
  #   55 tls-domains (Suricata tls.sni pass/drop) - domain allowlist/denylist
  #   90 dns (allow DNS to approved resolver; above deny so approved DNS passes first)
  #  100 deny (5-tuple drops)
  #  200 alert (alert-only suspicious traffic)
  #  400 allow (mgmt SSH, prod->shared logging)
  stateful_priorities = {
    allow = 400
    deny  = 100
    alert = 200
    dns   = 90
  }

  tls_domains_priority = 55

  tls_domains_count = (length(var.allowed_domains) > 0 || length(var.blocked_domains) > 0) ? 1 : 0

  stateful_refs = [
    for k, g in var.stateful_rule_groups : {
      key      = k
      priority = local.stateful_priorities[k]
      arn      = aws_networkfirewall_rule_group.stateful[k].arn
    }
  ]

  # Generate Suricata tls.sni rules from the allowed/blocked domain lists.
  # Native tls.sni rules provide flow-level pass/drop verdicts that work
  # reliably with alert_strict, unlike domain-list rule groups whose
  # asynchronous SNI evaluation races with the stateful default action.
  #   Allowed domains -> pass (flow-level, entire flow allowed)
  #   Blocked domains -> drop (flow-level, entire flow dropped)
  #   Unmatched HTTPS -> server response dropped by the catch-all rule
  tls_domain_rules = join("\n", concat(
    [for i, domain in var.allowed_domains :
      "pass tls $LAB_HOME_NET any -> $LAB_EXTERNAL_NET 443 (msg: \"LAB allow ${domain}\"; tls.sni; content:\"${domain}\"; sid: ${10000060 + i}; rev: 1;)"
    ],
    [for i, domain in var.blocked_domains :
      "drop tls $LAB_HOME_NET any -> $LAB_EXTERNAL_NET 443 (msg: \"LAB block ${domain}\"; tls.sni; content:\"${domain}\"; sid: ${10000050 + i}; rev: 1;)"
    ],
    [
      "drop tcp $LAB_EXTERNAL_NET 443 -> $LAB_HOME_NET any (msg: \"LAB drop unmatched HTTPS server response\"; flow:from_server,established; sid: 10000070; rev: 1;)"
    ],
  ))

  # Rule variables required by the tls.sni rules.
  tls_domain_rule_variables = {
    LAB_HOME_NET     = var.rule_variables.LAB_HOME_NET
    LAB_EXTERNAL_NET = var.rule_variables.LAB_EXTERNAL_NET
  }
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

# ----- TLS SNI domain rule group -----
#
# Uses native Suricata tls.sni rules instead of AWS Network Firewall domain-list
# rule groups. Domain-list rule groups evaluate SNI asynchronously, which races
# with the stateful default action: drop_established drops allowed traffic
# before the allowlist matches, and alert_strict passes blocked traffic before
# the denylist matches. Native tls.sni rules set flow-level pass/drop verdicts
# that are applied consistently once the SNI is parsed. The catch-all
# from_server drop rule blocks server responses for unmatched HTTPS domains.

resource "aws_networkfirewall_rule_group" "tls_domains" {
  count = (length(var.allowed_domains) > 0 || length(var.blocked_domains) > 0) ? 1 : 0

  # checkov:skip=CKV_AWS_345:Rule group encryption uses AWS-managed encryption; CMK not configured for this lab. Risk: no customer key control. Compensating control: AWS-managed encryption. Reviewer: configure CMK for production.

  name     = "${var.name}-tls-domains"
  capacity = var.domain_rule_group_capacity
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = local.tls_domain_rules
    }

    rule_variables {
      dynamic "ip_sets" {
        for_each = local.tls_domain_rule_variables

        content {
          key = ip_sets.key

          ip_set {
            definition = ip_sets.value
          }
        }
      }
    }

    stateful_rule_options {
      rule_order = var.stateful_rule_order
    }
  }

  tags = merge(local.module_tags, { Name = "${var.name}-tls-domains" })
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
      rule_order              = var.stateful_rule_order
      stream_exception_policy = var.stream_exception_policy
    }

    # 5-tuple stateful groups (allow/deny/alert/dns)
    dynamic "stateful_rule_group_reference" {
      for_each = { for r in local.stateful_refs : r.key => r }

      content {
        priority     = stateful_rule_group_reference.value.priority
        resource_arn = stateful_rule_group_reference.value.arn
      }
    }

    # tls-domains (Suricata tls.sni pass/drop), priority 55
    dynamic "stateful_rule_group_reference" {
      for_each = local.tls_domains_count > 0 ? { tls_domains = aws_networkfirewall_rule_group.tls_domains[0].arn } : {}

      content {
        priority     = local.tls_domains_priority
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