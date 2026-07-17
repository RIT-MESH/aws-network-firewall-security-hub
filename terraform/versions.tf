# Terraform and provider version constraints for the AWS Network Firewall
# Security Hub. Versions are constrained to a reviewed range rather than left
# open-ended. See AGENTS.md for the versioning policy.

terraform {
  required_version = ">= 1.5.0, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
