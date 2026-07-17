# Portfolio demonstration script

A 5-minute walkthrough.

1. **Problem**: centralized inspection for multi-VPC egress and east-west
   traffic with consistent policy.
2. **Architecture**: show `architecture/diagrams/architecture.mmd` and
   `architecture/architecture.md`; explain the inspection VPC, TGW, and
   workload VPCs.
3. **Routing**: show `architecture/routing-design.md`; explain why workloads
   cannot bypass inspection.
4. **Policy**: show `rules/README.md` and `rules/stateful/*.rules`; explain
   STRICT_ORDER priorities and the traffic-policy matrix.
5. **Logging/monitoring**: show `docs/firewall-logging.md`; CloudWatch + S3,
   dashboard, alarms.
6. **Validation**: run `make validate` and `pytest`; show 67+ passing tests and
   `terraform validate` success — all without AWS credentials.
7. **Honest status**: designed and statically validated; not deployed.

## Suggested release title

`aws-network-firewall-security-hub v0.1.0 — centralized inspection reference (statically validated)`