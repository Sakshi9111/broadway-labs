variable "bucket_name" {
  description = "Globally unique S3 bucket name. S3 bucket names cannot contain underscores."
  type        = string
  default     = "broadway-lab-s3"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters, use lowercase letters, numbers, and hyphens, and start/end with a letter or number."
  }
}

variable "aws_region" {
  description = "AWS region in which to create the bucket."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project tag applied to resources."
  type        = string
  default     = "broadway-lab"
}

variable "environment" {
  description = "Environment tag applied to resources."
  type        = string
  default     = "lab"
}
