# Logging module variables.
#
# Configures AWS Network Firewall operational logs (CloudWatch Logs) and
# encrypted S3 archival. Public access to the log bucket is fully blocked.

variable "name_prefix" {
  description = "Common resource name prefix."
  type        = string
}

variable "tags" {
  description = "Additional tags merged with module tags."
  type        = map(string)
  default     = {}
}

variable "enable_cloudwatch" {
  description = "Send firewall ALERT and FLOW logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "enable_s3_archival" {
  description = "Send firewall ALERT and FLOW logs to an encrypted S3 bucket for archival."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention in days for CloudWatch firewall log groups."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557], var.log_retention_days)
    error_message = "log_retention_days must be a supported CloudWatch Logs retention value."
  }
}

variable "s3_standard_ia_days" {
  description = "Days before objects transition to S3 Standard-IA."
  type        = number
  default     = 30
}

variable "s3_glacier_days" {
  description = "Days before objects transition to S3 Glacier Deep Archive."
  type        = number
  default     = 90
}

variable "s3_expiration_days" {
  description = "Days before objects expire from the log bucket. 0 disables expiration."
  type        = number
  default     = 365
}