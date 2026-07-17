# Module: test-workload

Optional private test instances gated by an enable toggle. No public IPs, SSM (no SSH), IMDSv2 required, EBS encrypted, least-privilege IAM, minimal security group, test-only user_data. Never stores SSH keys.

See variables.tf, main.tf, and outputs.tf for the implementation.