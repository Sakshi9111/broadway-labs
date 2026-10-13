data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "ec2" {
  source = "./modules/ec2"

  name          = "${var.project_name}-ec2"
  ami_id        = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
}

module "app_s3" {
  source = "./modules/s3"

  bucket_name = var.app_bucket_name
}
