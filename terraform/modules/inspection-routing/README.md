# Module: inspection-routing

Security-critical routing: per-AZ NAT Gateways, workload app default route to the Transit Gateway, firewall subnet default to NAT, firewall subnet spoke-CIDR routes to the Transit Gateway, and per-AZ TGW-attachment-to-firewall default routes. Prevents direct workload internet paths and preserves symmetric routing.

See variables.tf, main.tf, and outputs.tf for the implementation.