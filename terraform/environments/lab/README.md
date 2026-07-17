# Lab environment

Lower-cost reference composition for the centralized AWS Network Firewall
platform. This is the default environment for portfolio demonstration and
static validation.

This directory will become a Terraform root module that composes the modules
under `terraform/modules/`.

TODO (Phase 2+): add `main.tf`, `variables.tf`, and `outputs.tf` that compose:
1. VPCs (inspection, production, development, shared services)
2. Transit Gateway and attachments
3. Inspection routing
4. AWS Network Firewall and firewall policy
5. Logging and monitoring
6. Optional test workloads

See `terraform.tfvars.example` for example input values.
