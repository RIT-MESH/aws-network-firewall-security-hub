# Module: vpc

A reusable VPC module supporting VPC CIDR, name, environment, Availability Zones, and map-based definitions for private, firewall, Transit Gateway, and (when required) public subnets. Does not assume every VPC needs every subnet type. Optional VPC flow logs. Consistent tagging.

TODO (Phase 2+): implement main.tf, ariables.tf, outputs.tf, and ersions.tf (if module-local constraints are needed). No resources are declared in this Phase 1 foundation.
