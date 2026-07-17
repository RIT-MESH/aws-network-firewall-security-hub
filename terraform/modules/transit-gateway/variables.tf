# Transit Gateway module variables.
#
# The module is generic: callers describe attachments and route tables, and the
# module creates the Transit Gateway, VPC attachments, route tables,
# associations, propagations, and routes. Default route table association and
# propagation are disabled so that all routing is explicit and auditable.

variable "name" {
  description = "Name of the Transit Gateway."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be lowercase, start with a letter, and be 2-31 chars of [a-z0-9-]."
  }
}

variable "description" {
  description = "Description for the Transit Gateway."
  type        = string
  default     = "Centralized inspection Transit Gateway"
}

variable "amazon_side_asn" {
  description = "Amazon-side ASN for the Transit Gateway."
  type        = number
  default     = 64512

  validation {
    condition     = var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534
    error_message = "amazon_side_asn must be in the private 16-bit ASN range 64512-65534."
  }
}

variable "auto_accept_shared_attachments" {
  description = "Whether to auto-accept cross-account attachments. Keep disable for explicit control."
  type        = string
  default     = "disable"

  validation {
    condition     = contains(["enable", "disable"], var.auto_accept_shared_attachments)
    error_message = "auto_accept_shared_attachments must be enable or disable."
  }
}

variable "default_route_table_association" {
  description = "Disable so all associations are explicit."
  type        = string
  default     = "disable"
}

variable "default_route_table_propagation" {
  description = "Disable so all propagations are explicit."
  type        = string
  default     = "disable"
}

variable "dns_support" {
  description = "Enable DNS support on the Transit Gateway."
  type        = string
  default     = "enable"
}

variable "vpn_ecmp_support" {
  description = "Enable ECMP for VPNs. Keep disable unless multi-VPN redundancy is required."
  type        = string
  default     = "disable"
}

variable "tags" {
  description = "Additional tags merged with module tags."
  type        = map(string)
  default     = {}
}

variable "attachments" {
  description = <<EOT
Map of VPC attachments. Each entry:
  vpc_id        - VPC to attach
  subnet_ids    - one TGW attachment subnet per AZ
  appliance_mode - enable for the inspection VPC to preserve symmetric routing
EOT
  type = map(object({
    vpc_id         = string
    subnet_ids     = list(string)
    appliance_mode = bool
  }))
}

variable "route_tables" {
  description = <<EOT
Map of Transit Gateway route tables. Each entry:
  associations     - attachment keys to associate with this route table
  propagations    - attachment keys whose CIDRs propagate into this route table
  routes          - routes targeting another attachment
  blackhole_routes - destination CIDRs to blackhole
EOT
  type = map(object({
    associations = list(string)
    propagations = list(string)
    routes = list(object({
      destination       = string
      target_attachment = string
    }))
    blackhole_routes = list(string)
  }))
}