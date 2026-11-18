variable "aws_region" {
  description = "AWS region for this lab. Keep it aligned with backend.tf."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "broadway-lab"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "instance_type" {
  description = "EC2 instance type available in the chosen region."
  type        = string
  default     = "t3.micro"
}

variable "app_bucket_name" {
  description = "Globally unique application bucket name; use lowercase letters, digits, and hyphens."
  type        = string
  default     = "broadway-lab-s3"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.app_bucket_name))
    error_message = "Use a 3-63 character S3 bucket name with lowercase letters, numbers, and hyphens, starting and ending with a letter or number."
  }
}
