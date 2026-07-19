# Inspection routing module variables.
#
# This is a SECURITY-CRITICAL module. It creates the NAT gateways used for
# centralized egress and the route entries that force all workload and
# cross-VPC traffic through the inspection VPC and the AWS Network Firewall.
#
# Packet paths implemented:
#   - Workload app subnet default route -> Transit Gateway (no direct internet)
#   - TGW inspection attachment subnet default route -> per-AZ firewall endpoint
#   - Firewall subnet default route -> per-AZ NAT Gateway (internet egress)
#   - Firewall subnet spoke CIDR routes -> Transit Gateway (cross-VPC return)

variable "name_prefix" {
  description = "Common resource name prefix."
  type        = string
}

variable "tags" {
  description = "Additional tags merged with module tags."
  type        = map(string)
  default     = {}
}

variable "nat_enabled" {
  description = "Create NAT Gateways in the inspection public subnets for centralized egress."
  type        = bool
  default     = true
}

variable "inspection_public_subnet_ids" {
  description = "Map of AZ index (string) -> inspection public subnet ID, used for NAT Gateway placement."
  type        = map(string)
}

variable "inspection_firewall_route_table_ids" {
  description = "Map of AZ index (string) -> inspection firewall subnet route table ID."
  type        = map(string)
}

variable "inspection_tgw_route_table_ids" {
  description = "Map of AZ index (string) -> inspection TGW attachment subnet route table ID."
  type        = map(string)
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway that the inspection VPC is attached to."
  type        = string
}

variable "spoke_cidrs" {
  description = "Spoke VPC CIDRs that the firewall subnet must route back to the Transit Gateway for cross-VPC traffic."
  type        = list(string)
  default     = []
}

variable "workload_default_route_table_ids" {
  description = "App/private subnet route table IDs in workload VPCs that should default to the Transit Gateway."
  type        = list(string)
  default     = []
}

variable "firewall_routes_enabled" {
  description = "When true, create the per-AZ TGW-attachment-to-firewall default routes. Requires firewall_endpoint_ids_by_az to be supplied (Phase 4)."
  type        = bool
  default     = false
}

variable "firewall_endpoint_ids_by_az" {
  description = "Map of AZ index (string, e.g. \"0\",\"1\") -> Network Firewall endpoint ID. Keys MUST match the keys of inspection_tgw_route_table_ids so each TGW attachment subnet route table points to the same-AZ firewall endpoint deterministically (never a positional/list-index coupling)."
  type        = map(string)
  default     = {}
}
