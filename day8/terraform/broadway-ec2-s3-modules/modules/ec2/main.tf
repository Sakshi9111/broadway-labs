resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  # No key pair and no ingress security group are configured in this lab.
  # Add a reviewed security group and an access method only if needed.

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = var.name
  }
}
