# Module: ssm-vpc-endpoints

Creates AWS PrivateLink interface VPC endpoints for ssm, ssmmessages, and
ec2messages so instances in a workload VPC can register with AWS Systems Manager
without traversing the Network Firewall, Transit Gateway, NAT, or the public
internet.

- private_dns_enabled = true so regional SSM names resolve to endpoint ENIs.
- Dedicated endpoint SG: TCP 443 from the VPC CIDR only (no 0.0.0.0/0, no SSH/RDP); no egress rules (stateful return traffic).
- Region is passed in (var.region); not hardcoded.
- No routes added to Transit Gateway, Network Firewall, or any IGW.
