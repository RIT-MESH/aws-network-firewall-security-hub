variable "name_prefix" {
  description = "Common resource name prefix."
  type        = string
}

variable "vpc_id" {
  description = "ID of the workload VPC that will contain the endpoints."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR of the workload VPC; used as the ingress source for the endpoint security group (not 0.0.0.0/0)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (one or more per AZ) to associate with the interface endpoints."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 1
    error_message = "private_subnet_ids must contain at least one subnet."
  }
}

variable "region" {
  description = "AWS region used to build the SSM service endpoint names (com.amazonaws.<region>.<service>). Not hardcoded inside the module."
  type        = string
}

variable "tags" {
  description = "Additional tags merged with module tags."
  type        = map(string)
  default     = {}
}
