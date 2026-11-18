output "ec2_instance_id" {
  description = "ID of the EC2 instance."
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = module.ec2.private_ip
}

output "app_bucket_name" {
  description = "Application S3 bucket name."
  value       = module.app_s3.bucket_name
}

output "app_bucket_arn" {
  description = "Application S3 bucket ARN."
  value       = module.app_s3.bucket_arn
}
