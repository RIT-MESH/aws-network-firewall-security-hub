# AWS Network Firewall module variables.
#
# Creates a highly available firewall across the provided firewall subnets
# (one per AZ), attaches the supplied policy, and optionally configures log
# destinations. Protection flags are off by default and enabled by the
# production composition.

variable "name" {
  description = "Name of the AWS Network Firewall."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be lowercase, start with a letter, and be 2-31 chars of [a-z0-9-]."
  }
}

variable "description" {
  description = "Description for the firewall."
  type        = string
  default     = "Centralized AWS Network Firewall"
}

variable "vpc_id" {
  description = "ID of the inspection VPC hosting the firewall."
  type        = string
}

variable "subnet_ids" {
  description = "Firewall subnet IDs (one per Availability Zone)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids must contain at least 2 subnets for high availability."
  }
}

variable "az_names" {
  description = "Availability Zone names used to order endpoint IDs by AZ."
  type        = list(string)
}

variable "firewall_policy_arn" {
  description = "ARN of the AWS Network Firewall policy to attach."
  type        = string
}

variable "delete_protection" {
  description = "Prevent the firewall from being deleted. Enable in production."
  type        = bool
  default     = false
}

variable "subnet_change_protection" {
  description = "Prevent firewall subnet mappings from being changed. Enable in production."
  type        = bool
  default     = false
}

variable "firewall_policy_change_protection" {
  description = "Prevent the attached firewall policy from being changed. Enable in production."
  type        = bool
  default     = false
}

variable "logging_destinations" {
  description = <<EOT
Optional log destinations. Each entry:
  log_type            - ALERT or FLOW
  log_destination_type - CloudWatchLogs or S3
  log_destination     - map passed to the provider (e.g. { log_group = "name" } or { bucket_name = "name" })
EOT
  type = list(object({
    log_type             = string
    log_destination_type = string
    log_destination      = map(string)
  }))
  default = []
}

variable "tags" {
  description = "Additional tags merged with module tags."
  type        = map(string)
  default     = {}
}