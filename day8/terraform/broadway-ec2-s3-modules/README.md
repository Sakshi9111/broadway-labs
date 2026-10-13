# Broadway EC2 + S3 + Terraform modules + S3 backend

This lab creates:
- One Amazon Linux 2023 EC2 instance (no inbound ports opened)
- One private application S3 bucket with public access blocked, encryption, and versioning
- An S3 remote backend with native S3 state locking

## Important architecture note

The backend bucket must exist before Terraform can initialize the S3 backend. This lab bootstraps it with AWS CLI, then uses Terraform to manage the EC2 instance and application bucket. The backend bucket is intentionally separate from the application bucket.

## Prerequisites

- Terraform 1.10+ (for `use_lockfile = true`)
- AWS CLI v2
- AWS profile named `broadway-infosys`
- AWS permissions to create/configure S3 buckets and EC2 resources

Check your identity:

```bash
aws sts get-caller-identity --profile broadway-infosys
```

Choose a globally unique backend bucket name. S3 bucket names are globally unique and cannot contain underscores. Replace `YOUR-UNIQUE-SUFFIX` in the commands below with a unique value, such as a short random string. Do not use a bucket you do not own.

## Step 1 — Bootstrap the backend bucket

From this project directory, set a unique name. Keep it for all subsequent steps:

```bash
export AWS_PROFILE=broadway-infosys
export AWS_REGION=ap-south-1
export TF_STATE_BUCKET="broadway-tf-state-YOUR-UNIQUE-SUFFIX"
```

Create the bucket (for `us-east-1`, omit `--create-bucket-configuration`; this lab uses `ap-south-1`):

```bash
aws s3api create-bucket \
  --bucket "$TF_STATE_BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"
```

Enable versioning, encryption, and public-access protections:

```bash
aws s3api put-bucket-versioning \
  --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket "$TF_STATE_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-encryption \
  --bucket "$TF_STATE_BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

If creation reports `BucketAlreadyExists`, choose a different unique suffix and retry. If the command reports the bucket already exists and is owned by your account, verify it before proceeding.

## Step 2 — Configure backend

Edit `backend.tf` and replace `REPLACE_WITH_YOUR_UNIQUE_BACKEND_BUCKET` with the exact bucket name you created above.

The backend bucket must be in the region specified in `backend.tf`. Do not try to use Terraform variables inside the backend block; Terraform backend configuration is initialized separately.

## Step 3 — Configure variables

Copy the example file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- Pick a globally unique application bucket name (hyphens, not underscores).
- Choose a valid EC2 instance type available in your region.
- Keep the region consistent with your intended deployment.

## Step 4 — Initialize, plan, apply

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Review the plan before applying. This creates real AWS resources and may incur charges.

## What the modules demonstrate

- `modules/ec2`: module inputs (`ami_id`, `instance_type`, `name`) and outputs (`instance_id`, `private_ip`)
- `modules/s3`: module inputs and outputs, plus bucket encryption, versioning, and public access block
- Root module: calls both modules and exposes their outputs
- `backend.tf`: stores root state remotely in S3 and enables native S3 lock files

## Verify

```bash
terraform output
aws s3api head-bucket --bucket "$(terraform output -raw app_bucket_name)"
aws ec2 describe-instances \
  --profile broadway-infosys \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=broadway-lab-ec2" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table
```

## Destroy the lab

Destroy the resources managed by this root module:

```bash
terraform plan -destroy
terraform destroy
```

This does not delete the separately bootstrapped backend bucket. Keeping it avoids deleting the state that Terraform needs to track its own operations. Only remove the backend bucket after you have intentionally migrated or no longer need its state; ensure it is empty and preserve any state history you need.

## Security notes

- This EC2 instance has no security group or ingress rules created by this project; no inbound network access is opened.
- No SSH key is configured. Use a separately designed access method (for example, Systems Manager with a properly configured instance role and network connectivity) if you need shell access.
- State may contain sensitive data. Restrict backend access and never commit state or plan files.
- This is a learning lab, not a complete production baseline.
