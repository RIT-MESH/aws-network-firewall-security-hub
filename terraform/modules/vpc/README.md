# Module: vpc

Reusable VPC module. Map-driven subnet definitions (private, firewall, tgw, public), per-subnet route tables, optional Internet Gateway (inspection only), optional VPC flow logs, DNS support/hostnames, consistent tagging. Does not assume every VPC needs every subnet type.

See variables.tf, main.tf, and outputs.tf for the implementation.