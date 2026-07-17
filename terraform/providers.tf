# AWS provider configuration. Default tags are applied to all taggable
# resources so that ownership, environment, and purpose are consistent across
# the platform. Region is driven by a validated variable; no credentials are
# hardcoded here.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
