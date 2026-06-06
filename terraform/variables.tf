variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile name"
  default     = "default"
}

variable "project_name" {
  type        = string
  description = "Project name used as prefix for resource names"
  default     = "mtls-sample"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the verification environment"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB (minimum 2 AZs required)"
}

variable "private_subnet_id" {
  type        = string
  description = "Private subnet ID for the EC2 instance"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the ALB HTTPS listener"
}

variable "ca_bundle_local_path" {
  type        = string
  description = "Local path to the CA bundle PEM file to upload to S3"
  default     = "../key/ca-bundle.pem"
}
