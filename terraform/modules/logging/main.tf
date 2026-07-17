locals {
  module_tags = merge(var.tags, {
    Module = "logging"
  })

  bucket_name = "${var.name_prefix}-firewall-logs"
}

# ----- CloudWatch Logs groups -----

resource "aws_cloudwatch_log_group" "alert" {
  count = var.enable_cloudwatch ? 1 : 0

  name              = "/aws/network-firewall/${var.name_prefix}/alert"
  retention_in_days = var.log_retention_days
  tags              = merge(local.module_tags, { Name = "${var.name_prefix}-firewall-alert-logs" })
}

resource "aws_cloudwatch_log_group" "flow" {
  count = var.enable_cloudwatch ? 1 : 0

  name              = "/aws/network-firewall/${var.name_prefix}/flow"
  retention_in_days = var.log_retention_days
  tags              = merge(local.module_tags, { Name = "${var.name_prefix}-firewall-flow-logs" })
}

# CloudWatch Logs resource policy allowing AWS Network Firewall to write logs.
resource "aws_cloudwatch_log_resource_policy" "firewall" {
  count = var.enable_cloudwatch ? 1 : 0

  policy_name = "${var.name_prefix}-firewall-cw-resource-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "networkfirewall.amazonaws.com"
      }
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = [
        aws_cloudwatch_log_group.alert[0].arn,
        aws_cloudwatch_log_group.flow[0].arn,
      ]
    }]
  })
}

# ----- S3 archival bucket -----

resource "aws_s3_bucket" "logs" {
  count = var.enable_s3_archival ? 1 : 0

  bucket = local.bucket_name
  tags   = merge(local.module_tags, { Name = local.bucket_name })
}

resource "aws_s3_bucket_versioning" "logs" {
  count = var.enable_s3_archival ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = var.enable_s3_archival ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = var.enable_s3_archival ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count = var.enable_s3_archival ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = var.enable_s3_archival ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "firewall-logs-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = var.s3_standard_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.s3_glacier_days
      storage_class = "DEEP_ARCHIVE"
    }

    dynamic "expiration" {
      for_each = var.s3_expiration_days > 0 ? [1] : []

      content {
        days = var.s3_expiration_days
      }
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Bucket policy allowing AWS log delivery to write Network Firewall logs.
resource "aws_s3_bucket_policy" "logs" {
  count = var.enable_s3_archival ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "delivery.logs.amazonaws.com"
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.logs[0].arn}/AWSLogs/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl" = "bucket-owner-full-control"
        }
      }
    }]
  })
}