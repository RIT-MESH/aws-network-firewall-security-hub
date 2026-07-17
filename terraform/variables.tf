# Project-wide variables. Every variable has a type, a description, and
# validation where a constrained value is appropriate. Sensitive variables
# are marked with sensitive = true.

variable "environment" {
  description = "Deployment environment name used in resource naming and tags. Drives the resource name prefix anfw-<environment>."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.environment))
    error_message = "environment must be lowercase, start with a letter, and be 2-31 chars of [a-z0-9-]."
  }
}

variable "owner" {
  description = "Owner label applied to all resources via common tags. Use a team or individual identifier, not a secret."
  type        = string
  default     = "platform-team"

  validation {
    condition     = length(var.owner) > 0 && length(var.owner) <= 64
    error_message = "owner must be 1-64 characters."
  }
}

variable "aws_region" {
  description = "AWS region for all resources. Must be a valid region string."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier such as us-east-1 or us-gov-west-1."
  }
}

variable "additional_tags" {
  description = "Additional tags merged on top of the common tags. Use for cost-center, business-unit, etc."
  type        = map(string)
  default     = {}
}

variable "availability_zone_count" {
  description = "Number of Availability Zones to use. The architecture targets high availability and requires at least 2."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 4
    error_message = "availability_zone_count must be between 2 and 4 for high availability."
  }
}

# ----- VPC CIDRs -----
variable "inspection_vpc_cidr" {
  description = "CIDR block for the inspection VPC (firewall, TGW attachments, public/NAT subnets)."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.inspection_vpc_cidr, 0))
    error_message = "inspection_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "production_vpc_cidr" {
  description = "CIDR block for the production VPC (private application + TGW attachment subnets)."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.production_vpc_cidr, 0))
    error_message = "production_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "development_vpc_cidr" {
  description = "CIDR block for the development VPC (private application + TGW attachment subnets)."
  type        = string
  default     = "10.2.0.0/16"

  validation {
    condition     = can(cidrhost(var.development_vpc_cidr, 0))
    error_message = "development_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "shared_services_vpc_cidr" {
  description = "CIDR block for the shared-services VPC (private shared-services + TGW attachment subnets)."
  type        = string
  default     = "10.3.0.0/16"

  validation {
    condition     = can(cidrhost(var.shared_services_vpc_cidr, 0))
    error_message = "shared_services_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

# ----- VPC flow logs -----
variable "vpc_flow_logs_enabled" {
  description = "Enable VPC flow logs for each VPC to a dedicated CloudWatch Logs group."
  type        = bool
  default     = false
}

variable "vpc_flow_log_retention_days" {
  description = "Retention in days for VPC flow log groups when flow logs are enabled."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557], var.vpc_flow_log_retention_days)
    error_message = "vpc_flow_log_retention_days must be a supported CloudWatch Logs retention value."
  }
}

# ----- Firewall policy / firewall -----

variable "stateful_rule_order" {
  description = "Stateful rule evaluation order. STRICT_ORDER evaluates rule groups by priority and stops at the first match."
  type        = string
  default     = "STRICT_ORDER"

  validation {
    condition     = contains(["STRICT_ORDER", "DEFAULT_ACTION_ORDER"], var.stateful_rule_order)
    error_message = "stateful_rule_order must be STRICT_ORDER or DEFAULT_ACTION_ORDER."
  }
}

variable "stateful_rule_group_capacity" {
  description = "Capacity for each 5-tuple stateful rule group (allow/deny/alert/dns)."
  type        = number
  default     = 100

  validation {
    condition     = var.stateful_rule_group_capacity > 0 && var.stateful_rule_group_capacity <= 100000
    error_message = "stateful_rule_group_capacity must be between 1 and 100000."
  }
}

variable "domain_rule_group_capacity" {
  description = "Capacity for the allowed/blocked domain-list rule groups."
  type        = number
  default     = 100

  validation {
    condition     = var.domain_rule_group_capacity > 0 && var.domain_rule_group_capacity <= 100000
    error_message = "domain_rule_group_capacity must be between 1 and 100000."
  }
}

variable "firewall_delete_protection" {
  description = "Prevent the firewall from being deleted. Enable in production."
  type        = bool
  default     = false
}

variable "firewall_subnet_change_protection" {
  description = "Prevent firewall subnet mappings from being changed. Enable in production."
  type        = bool
  default     = false
}

variable "firewall_policy_change_protection" {
  description = "Prevent the attached firewall policy from being changed. Enable in production."
  type        = bool
  default     = false
}
# ----- Logging / monitoring -----

variable "firewall_log_retention_days" {
  description = "Retention in days for CloudWatch firewall log groups."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557], var.firewall_log_retention_days)
    error_message = "firewall_log_retention_days must be a supported CloudWatch Logs retention value."
  }
}

variable "enable_firewall_cloudwatch_logs" {
  description = "Send firewall ALERT and FLOW logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "enable_firewall_s3_archival" {
  description = "Send firewall ALERT and FLOW logs to an encrypted S3 bucket for archival."
  type        = bool
  default     = true
}

variable "firewall_s3_standard_ia_days" {
  description = "Days before firewall log objects transition to S3 Standard-IA."
  type        = number
  default     = 30
}

variable "firewall_s3_glacier_days" {
  description = "Days before firewall log objects transition to S3 Glacier Deep Archive."
  type        = number
  default     = 90
}

variable "firewall_s3_expiration_days" {
  description = "Days before firewall log objects expire. 0 disables expiration."
  type        = number
  default     = 365
}

variable "enable_monitoring_sns" {
  description = "Create an SNS topic for CloudWatch alarm notifications."
  type        = bool
  default     = false
}

variable "firewall_alert_volume_threshold" {
  description = "Firewall alerts per 5-minute period that triggers an alarm."
  type        = number
  default     = 100
}

variable "firewall_dropped_packet_threshold" {
  description = "Dropped packets per 5-minute period that triggers an alarm."
  type        = number
  default     = 500
}
# ----- Test workloads (Phase 6) -----

variable "enable_test_workloads" {
  description = "Create optional private test instances for traffic validation. Disabled by default to avoid cost."
  type        = bool
  default     = false
}

variable "test_instance_type" {
  description = "EC2 instance type for optional test workloads. Keep small for cost."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.test_instance_type))
    error_message = "test_instance_type must be a valid EC2 instance type (e.g., t3.micro)."
  }
}