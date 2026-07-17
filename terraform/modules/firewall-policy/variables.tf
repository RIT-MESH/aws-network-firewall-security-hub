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

variable "stateless_default_actions" {
  description = "Default action for stateless traffic that matches no stateless rule."
  type        = list(string)
  default     = ["aws:drop"]
}

variable "stateless_fragment_default_actions" {
  description = "Default action for stateless fragmented traffic that matches no stateless rule."
  type        = list(string)
  default     = ["aws:drop"]
}

variable "stateful_default_actions" {
  description = "Default action for stateful traffic that matches no stateful rule. Must be a strict action when stateful_rule_order is STRICT_ORDER."
  type        = list(string)
  default     = ["aws:drop_strict"]
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