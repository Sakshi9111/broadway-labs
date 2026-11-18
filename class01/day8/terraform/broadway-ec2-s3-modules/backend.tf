terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_YOUR_UNIQUE_BACKEND_BUCKET"
    key          = "broadway-lab/dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
