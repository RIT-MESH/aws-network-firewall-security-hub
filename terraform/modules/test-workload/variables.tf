# Optional test workload module.
#
# Creates private test instances in workload VPCs for traffic validation. All
# resources are gated by `enabled` so the entire test fleet can be disabled.
# Instances have no public IP, require IMDSv2, encrypt EBS, and use SSM (no
# public SSH). No SSH private keys are created or stored.

variable "name_prefix" {
  description = "Common resource name prefix."
  type        = string
}

variable "tags" {
  description = "Additional tags merged with module tags."
  type        = map(string)
  default     = {}
}

variable "enabled" {
  description = "Master toggle. When false, no test instances, roles, or security groups are created."
  type        = bool
  default     = false
}

variable "instances" {
  description = <<EOT
Map of test instances. Each entry:
  name      - instance logical name
  subnet_id - private app subnet id (no public IP)
  vpc_id    - VPC id for the instance security group
EOT
  type = map(object({
    name      = string
    subnet_id = string
    vpc_id    = string
  }))
  default = {}
}

variable "instance_type" {
  description = "EC2 instance type for test workloads. Keep small for cost."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must be a valid EC2 instance type (e.g., t3.micro)."
  }
}

variable "volume_size_gb" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.volume_size_gb >= 8 && var.volume_size_gb <= 100
    error_message = "volume_size_gb must be between 8 and 100."
  }
}

variable "ami_ssm_parameter" {
  description = "SSM parameter name for the AMI id (Amazon Linux 2023 by default)."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}