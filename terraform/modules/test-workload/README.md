# Module: test-workload

Optional low-cost private test workloads. No public IPs, SSM preferred over public SSH, minimal configurable instance type, least-privilege IAM, encrypted root volume, IMDSv2 required, minimal security group, and a toggle to disable all test instances. Never stores SSH private keys.

TODO (Phase 2+): implement main.tf, ariables.tf, outputs.tf, and ersions.tf (if module-local constraints are needed). No resources are declared in this Phase 1 foundation.
