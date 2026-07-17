# Production environment

Hardened tfvars: firewall delete/subnet/policy change protection enabled,
STRICT_ORDER, CloudWatch + S3 logging. Copy `terraform.tfvars.example` to
`terraform/terraform.tfvars`. See `docs/security-decisions.md`.
