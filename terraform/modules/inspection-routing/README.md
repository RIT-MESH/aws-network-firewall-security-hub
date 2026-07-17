# Module: inspection-routing

Security-critical routing module. Routes workload default traffic to Transit Gateway, Transit Gateway traffic to the inspection VPC, inspected outbound traffic to NAT Gateway, and return traffic through the same firewall path. Prevents direct workload internet paths and preserves symmetric routing. Every non-obvious route is commented.

TODO (Phase 2+): implement main.tf, ariables.tf, outputs.tf, and ersions.tf (if module-local constraints are needed). No resources are declared in this Phase 1 foundation.
