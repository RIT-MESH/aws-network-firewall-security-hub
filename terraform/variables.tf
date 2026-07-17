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
