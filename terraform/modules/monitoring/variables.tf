# Monitoring module variables.
#
# Creates a CloudWatch dashboard, log metric filters, alarms for firewall alert
# volume and dropped-traffic spikes, and an optional SNS notification topic.

variable "name_prefix" {
  description = "Common resource name prefix."
  type        = string
}

variable "aws_region" {
  description = "AWS region used for CloudWatch dashboard widget defaults."
  type        = string
}

variable "tags" {
  description = "Additional tags merged with module tags."
  type        = map(string)
  default     = {}
}

variable "firewall_name" {
  description = "Name of the AWS Network Firewall, used as the CloudWatch metric dimension."
  type        = string
}

variable "alert_log_group_name" {
  description = "CloudWatch log group name for firewall ALERT logs (for metric filters). May be null."
  type        = string
  default     = null
}

variable "flow_log_group_name" {
  description = "CloudWatch log group name for firewall FLOW logs (for metric filters). May be null."
  type        = string
  default     = null
}

variable "enable_sns" {
  description = "Create an SNS topic for alarm notifications."
  type        = bool
  default     = false
}

variable "alert_volume_threshold" {
  description = "Number of firewall alerts per 5-minute period that triggers an alarm."
  type        = number
  default     = 100
}

variable "dropped_packet_threshold" {
  description = "Number of dropped packets per 5-minute period that triggers an alarm."
  type        = number
  default     = 500
}