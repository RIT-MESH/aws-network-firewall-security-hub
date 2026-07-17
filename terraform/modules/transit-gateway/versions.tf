# Module-level Terraform and provider constraints (mirrors the root module).
terraform {
  required_version = ">= 1.5.0, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
