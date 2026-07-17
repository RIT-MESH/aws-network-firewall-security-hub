# Shared locals: common tags and a consistent naming prefix. The naming prefix
# follows the project convention:
#   <project-short>-<environment>-<component>-<az-or-purpose>
# for example: anfw-lab-inspection-vpc, anfw-lab-prod-app-a, anfw-lab-tgw.

locals {
  project_name = "aws-network-firewall-security-hub"
  name_prefix  = "anfw-${var.environment}"

  common_tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    Purpose     = "CloudNetworkSecurityLab"
  }

  # Merged tags allow callers to add additional tags on top of the common set.
  merged_tags = merge(local.common_tags, var.additional_tags)
}
