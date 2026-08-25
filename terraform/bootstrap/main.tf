resource "aws_s3_bucket" "state" {
  # checkov:skip=CKV2_AWS_62:State change monitoring via CI; no bucket notifications in the lab.
  # checkov:skip=CKV_AWS_18:No separate log bucket in this cost-limited lab.
  # checkov:skip=CKV_AWS_144:Single-region academic lab; versioning protects against accidental overwrite.
  # checkov:skip=CKV_AWS_145:SSE-S3 AES256 already configured; customer-managed KMS not used in lab.
  bucket = var.state_bucket_name
  tags = {
    Project   = "TrabalhoFinalInfra"
    ManagedBy = "terraform"
    Purpose   = "remote-state"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-old-noncurrent-versions"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket" "ssm_transfer" {
  # checkov:skip=CKV2_AWS_62:Ephemeral SSM transport bucket expires objects after one day.
  # checkov:skip=CKV_AWS_18:No separate log bucket in this cost-limited lab.
  # checkov:skip=CKV_AWS_144:Temporary SSM transport must not replicate files containing module payloads.
  # checkov:skip=CKV_AWS_145:SSE-S3 AES256 already configured; customer-managed KMS not used in lab.
  # checkov:skip=CKV_AWS_21:Ansible SSM forbids version history retaining transferred modules and secrets.
  bucket = var.ssm_transfer_bucket_name
  tags = {
    Project   = "TrabalhoFinalInfra"
    ManagedBy = "terraform"
    Purpose   = "ansible-ssm-transfer"
  }
}

resource "aws_s3_bucket_public_access_block" "ssm_transfer" {
  bucket                  = aws_s3_bucket.ssm_transfer.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id
  rule {
    id     = "expire-abandoned-transfers"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    expiration {
      days = 1
    }
  }
}
