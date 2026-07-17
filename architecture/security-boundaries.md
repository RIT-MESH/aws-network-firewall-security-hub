# Security boundaries

## Trust zones

| Zone | Networks | Trust |
| --- | --- | --- |
| Internet | 0.0.0.0/0 outside AWS | untrusted |
| Inspection public | inspection public subnets + IGW + NAT | semi-trusted (egress only) |
| Firewall | inspection firewall subnets | enforcement point |
| Workloads | production, development, shared services private subnets | restricted |
| Management | shared services (admin/SSM) | restricted, no public ingress |

## Boundaries enforced

- Workload VPCs have no Internet Gateway; egress only via TGW -> inspection ->
  firewall -> NAT -> IGW. Bypass is not possible from a workload.
- Cross-VPC traffic is forced through the firewall (workload/shared TGW route
  tables default to the inspection attachment).
- No SSH/RDP is exposed to 0.0.0.0/0. Test instances use SSM Session Manager.
- Test instances have no public IP, require IMDSv2, and encrypt EBS.
- S3 log bucket blocks all public access, enforces BucketOwnerEnforced, and is
  encrypted.
- Least-privilege IAM: test instance role only has AmazonSSMManagedInstanceCore.

## Compensating controls

- Centralized inspection is the primary control; defense-in-depth via VPC
  flow logs (optional) and CloudWatch metric filters/alarms.
- Production composition enables firewall delete/subnet/policy change
  protection to prevent accidental tampering.