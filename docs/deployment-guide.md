# Deployment guide

Deployment is staged. Never run `terraform apply` or `terraform destroy`
without explicit human approval.

## Stage 1: Static validation (no AWS credentials)

```bash
make validate
# or
scripts/validate.sh
```

## Stage 2: Read-only planning (AWS credentials required)

```bash
cd terraform
terraform init
cp ../terraform/environments/lab/terraform.tfvars.example terraform.tfvars  # adjust
terraform plan -out=tfplan
```

Never commit `tfplan` (it is gitignored).

## Stage 3: Human-reviewed deployment

After reviewing the plan:

```bash
terraform apply tfplan
```

Codex never performs this step automatically.

## Stage 4: Traffic validation

Enable test workloads (`enable_test_workloads = true`) and run:

```bash
scripts/test-connectivity.sh --run
python scripts/generate-test-traffic.py --scenario allowed-https
```

## Stage 5: Evidence capture

Capture sanitized: terraform output, route tables, firewall policy, CloudWatch
alert samples, test results, dashboard screenshots.

## Stage 6: Cleanup (explicit approval)

```bash
terraform destroy
```

### Cleanup order and retained resources

1. Set `enable_test_workloads = false` and apply to remove test instances.
2. Destroy the firewall and routing (destroys NAT, firewall, TGW, VPCs).
3. Logging resources (CloudWatch log groups, S3 bucket) are retained by default
   to preserve evidence; remove them manually after review if desired.

## Environments

This repository uses a single Terraform root at `terraform/` and selects an
environment via `terraform.tfvars`. Example tfvars live in
`terraform/environments/lab/` and `terraform/environments/production/`.
Production tfvars enable firewall protection flags.