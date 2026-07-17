# Central composition root for the AWS Network Firewall Security Hub.
#
# This file composes the reusable modules under terraform/modules/ in the
# correct dependency order:
#   1. VPCs (inspection, production, development, shared services)
#   2. Transit Gateway and VPC attachments
#   3. Inspection routing (security-critical)
#   4. AWS Network Firewall and firewall policy
#   5. Logging and monitoring
#   6. Optional test workloads
#
# Module composition is added in Phase 2 and later. No AWS resources are
# declared in this Phase 1 foundation on purpose.
