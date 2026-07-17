# Reusable VPC module variables.
# This module does not assume every VPC needs every subnet type. Callers pass
# a map of subnet definitions; only the subnets they declare are created.

variable "vpc_name" {
  description = "Name of the VPC and base name for child resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.vpc_name))
    error_message = "vpc_name must be lowercase, start with a letter, and be 2-31 chars of [a-z0-9-]."
  }
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_names" {
  description = "Availability Zone names to use. Must contain at least 2 entries for high availability."
  type        = list(string)

  validation {
    condition     = length(var.az_names) >= 2
    error_message = "az_names must contain at least 2 Availability Zones."
  }
}

variable "subnets" {
  description = <<EOT
Map of subnet definitions. Each entry:
  cidr           - CIDR block
  az_index        - 0-based index into az_names
  purpose         - free-form label (firewall, tgw, public, app, shared, etc.)
  map_public_ip   - true to map public IPs on launch (public subnets only)
EOT
  type = map(object({
    cidr          = string
    az_index      = number
    purpose       = string
    map_public_ip = bool
  }))
}

variable "enable_dns_support" {
  description = "Enable AWS DNS support in the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable AWS DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "create_internet_gateway" {
  description = "Create an Internet Gateway and a default 0.0.0.0/0 route for subnets with map_public_ip = true. Set true only for the inspection VPC."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to a dedicated CloudWatch Logs group."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Retention in days for the VPC flow log group when flow logs are enabled."
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a supported CloudWatch Logs retention value."
  }
}

variable "tags" {
  description = "Additional tags merged with module tags. Common tags are provided by the caller."
  type        = map(string)
  default     = {}
}
