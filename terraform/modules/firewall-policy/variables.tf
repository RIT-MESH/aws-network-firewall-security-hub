# Firewall policy module variables.
#
# This module creates the AWS Network Firewall policy, the stateful Suricata
# rule groups (allow/deny/alert/dns), the domain-list rule groups (allowed and
# blocked), and a stateless rule group that drops documentation-only blocked
# destination CIDRs. Stateful evaluation uses STRICT_ORDER with explicit
# priorities documented in rules/README.md.

variable "name" {
  description = "Name of the firewall policy and base name for rule groups."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be lowercase, start with a letter, and be 2-31 chars of [a-z0-9-]."
  }
}

variable "description" {
  description = "Description for the firewall policy."
  type        = string
  default     = "Centralized AWS Network Firewall policy"
}

variable "tags" {
  description = "Additional tags merged with module tags."
  type        = map(string)
  default     = {}
}

variable "stateful_rule_order" {
  description = "Stateful rule evaluation order. STRICT_ORDER evaluates rule groups by priority and stops at the first match."
  type        = string
  default     = "STRICT_ORDER"

  validation {
    condition     = contains(["STRICT_ORDER", "DEFAULT_ACTION_ORDER"], var.stateful_rule_order)
    error_message = "stateful_rule_order must be STRICT_ORDER or DEFAULT_ACTION_ORDER."
  }
}

variable "stream_exception_policy" {
  description = "Stream exception policy for the stateful engine. CONTINUE lets the engine pass the TCP handshake until it can inspect application-layer data (e.g. TLS SNI for domain-list rules) before applying the stateful default; this is required for TLS_SNI/HTTP_HOST domain-list rules to evaluate under a drop_strict stateful default. DROP would drop unclassified packets (e.g. the SYN before the SNI) and prevent domain-list inspection. The stateful default (drop_strict) still denies unmatched traffic."
  type        = string
  default     = "CONTINUE"

  validation {
    condition     = contains(["DROP", "CONTINUE"], var.stream_exception_policy)
    error_message = "stream_exception_policy must be DROP or CONTINUE."
  }
}

variable "stateless_default_actions" {
  description = "Default action for stateless traffic that matches no stateless rule. Must forward to the stateful engine (aws:forward_to_sfe) so the configured stateful allow/deny/alert/DNS/domain-list policies can evaluate traffic; a stateless aws:drop default would drop all traffic before stateful evaluation and silently bypass the entire stateful policy."
  type        = list(string)
  default     = ["aws:forward_to_sfe"]

  validation {
    condition     = contains(var.stateless_default_actions, "aws:forward_to_sfe")
    error_message = "stateless_default_actions must contain aws:forward_to_sfe so unmatched stateless traffic reaches the stateful engine. A bare aws:drop default bypasses the stateful policy."
  }
}

variable "stateless_fragment_default_actions" {
  description = "Default action for stateless fragmented traffic that matches no stateless rule. Must forward to the stateful engine (aws:forward_to_sfe) for the same reason as stateless_default_actions."
  type        = list(string)
  default     = ["aws:forward_to_sfe"]

  validation {
    condition     = contains(var.stateless_fragment_default_actions, "aws:forward_to_sfe")
    error_message = "stateless_fragment_default_actions must contain aws:forward_to_sfe so unmatched fragmented traffic reaches the stateful engine."
  }
}

variable "stateful_default_actions" {
  description = "Default action for stateful traffic that matches no stateful rule. alert_strict alerts (but does not drop) unmatched stateful traffic, allowing the TCP handshake and TLS ClientHello to pass while the Suricata tls.sni rules evaluate the SNI. Unmatched HTTPS is denied by the catch-all from_server drop rule in the tls-domains rule group. This is required because domain-list SNI evaluation is asynchronous: drop_established drops allowed traffic before the allowlist matches, and alert_strict alone would pass blocked traffic before the denylist matches."
  type        = list(string)
  default     = ["aws:alert_strict"]
}

variable "rule_variables" {
  description = "Map of Suricata rule variable name -> list of CIDR definitions, exposed to stateful rules as $<name>."
  type        = map(list(string))
  default     = {}
}

variable "stateful_rule_groups" {
  description = <<EOT
Map of stateful Suricata rule groups. Key is the group name (allow, deny, alert, dns).
Each entry:
  rules    - raw Suricata rules string
  capacity - rule group capacity
EOT
  type = map(object({
    rules    = string
    capacity = number
  }))
  default = {}
}

variable "allowed_domains" {
  description = "Domains allowed for HTTP/HTTPS egress (ALLOWLIST). All other HTTP/HTTPS egress is dropped."
  type        = list(string)
  default     = []
}

variable "blocked_domains" {
  description = "Domains explicitly blocked (DENYLIST)."
  type        = list(string)
  default     = []
}

variable "domain_rule_group_capacity" {
  description = "Capacity for the allowed/blocked domain-list rule groups."
  type        = number
  default     = 100
}

variable "blocked_destinations" {
  description = "Destination CIDRs to drop with a stateless rule group (documentation-only TEST-NET ranges)."
  type        = list(string)
  default     = []
}

variable "stateless_rule_group_capacity" {
  description = "Capacity for the stateless drop rule group."
  type        = number
  default     = 100
}
