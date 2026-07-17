# Production environment

Production-style composition with protection flags enabled by default (firewall
delete protection, subnet-change protection, and firewall-policy-change
protection). Use this composition to demonstrate hardened settings.

This directory will become a Terraform root module that composes the modules
under `terraform/modules/`.

TODO (Phase 2+): add `main.tf`, `variables.tf`, and `outputs.tf`. The
production composition MUST enable the Network Firewall protection settings by
default and avoid public IP assignment on workload instances.

See `terraform.tfvars.example` for example input values.
