# AGENTS.md

## Project purpose

This repository implements a centralized multi-VPC AWS security architecture using AWS Network Firewall, Transit Gateway, Terraform, Suricata-compatible rules, CloudWatch, and S3.

## Operating rules

- Inspect existing code before modifying it.
- Preserve module boundaries.
- Keep Terraform modules small and reusable.
- Never commit credentials, state files, plan files, or private keys.
- Never run terraform apply or destroy without explicit approval.
- Static validation must work without AWS credentials.
- Update documentation whenever behavior changes.
- Add or update tests for every security-sensitive change.
- Explain routing implications for any route-table change.
- Explain firewall implications for any rule-policy change.
- Use least privilege.
- Deny cross-VPC access unless explicitly permitted.
- Do not expose SSH or RDP to the public internet.

## Required checks

Run as many of these as are available:

- terraform fmt -check -recursive
- terraform init -backend=false
- terraform validate
- tflint --recursive
- checkov -d terraform
- tfsec terraform
- pytest
- shellcheck scripts/*.sh
- markdownlint .
- yamllint .
- pre-commit run --all-files

## Code style

- Use descriptive Terraform resource names.
- Define common names and tags in locals.
- Include descriptions for variables and outputs.
- Add validation blocks for constrained variables.
- Pin Terraform and provider versions.
- Avoid unnecessary provider aliases.
- Prefer for_each over count for named resources.
- Do not use provisioners unless unavoidable.
- Do not use remote-exec.
- Format all files before completion.

## Security-sensitive files

Changes to these files require additional review:

- terraform/modules/network-firewall/
- terraform/modules/firewall-policy/
- terraform/modules/inspection-routing/
- rules/
- terraform/modules/transit-gateway/

## Completion format

At the end of each task report:

1. Files changed
2. Behavior implemented
3. Tests run
4. Test results
5. Remaining risks
6. Suggested next task
