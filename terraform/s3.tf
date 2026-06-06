resource "aws_s3_bucket" "ca_bundle" {
  bucket_prefix = "${var.project_name}-ca-bundle"

  tags = {
    Name = "${var.project_name}-ca-bundle"
  }
}

resource "aws_s3_bucket_versioning" "ca_bundle" {
  bucket = aws_s3_bucket.ca_bundle.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ca_bundle" {
  bucket = aws_s3_bucket.ca_bundle.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ca_bundle" {
  bucket = aws_s3_bucket.ca_bundle.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "ca_bundle" {
  bucket = aws_s3_bucket.ca_bundle.id
  key    = "ca-bundle.pem"
  source = var.ca_bundle_local_path
  etag   = filemd5(var.ca_bundle_local_path)

  depends_on = [
    aws_s3_bucket_versioning.ca_bundle,
    aws_s3_bucket_server_side_encryption_configuration.ca_bundle,
  ]
}

resource "aws_lb_trust_store" "mtls" {
  name                             = "${var.project_name}-trust-store"
  ca_certificates_bundle_s3_bucket = aws_s3_bucket.ca_bundle.bucket
  ca_certificates_bundle_s3_key    = aws_s3_object.ca_bundle.key

  depends_on = [aws_s3_object.ca_bundle]

  tags = {
    Name = "${var.project_name}-trust-store"
  }
}
