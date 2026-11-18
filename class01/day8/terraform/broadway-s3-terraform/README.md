# Broadway S3 bucket — Terraform

This project provisions an S3 bucket with:
- S3 Block Public Access enabled
- Bucket-owner-enforced object ownership (ACLs disabled)
- Default server-side encryption (SSE-S3 / AES256)
- Bucket versioning enabled
- `force_destroy = false` to help prevent accidental deletion of stored objects
- Default project, environment, and Terraform tags

## Important naming note

S3 bucket names must be globally unique and cannot contain underscores. The requested
`broadway_lab_s3` name is invalid, so the default is `broadway-lab-s3`. If another AWS
customer already owns that name, choose a unique name, for example
`broadway-lab-s3-<your-unique-suffix>`.

## Prerequisites

1. Install Terraform (1.5 or newer).
2. Install and configure the AWS CLI, or provide AWS credentials through your organization's
   approved credential mechanism.
3. Ensure the identity you use has permission to create and configure S3 buckets and to
   read bucket configuration. Do not put access keys in Terraform files.

Check your active identity:

```bash
aws sts get-caller-identity
```

## Configure

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` if you need a different globally unique bucket name or AWS region.

## Validate and deploy

Run from this directory:

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Review the plan carefully before applying. Applying creates real AWS resources and may incur
charges for storage, requests, and retained object versions.

Read the outputs:

```bash
terraform output
```

## Upload a test object

After deployment, replace the local file path as needed:

```bash
echo "Broadway lab test" > test.txt
aws s3 cp test.txt "s3://$(terraform output -raw bucket_name)/test.txt"
aws s3 ls "s3://$(terraform output -raw bucket_name)/"
```

## Destroy

First remove any objects and object versions you want to keep. Versioning is enabled and
`force_destroy = false`, so Terraform will not automatically empty the bucket for you.

```bash
terraform plan -destroy
terraform destroy
```

Review the destroy plan before confirming. Back up any data you need before deleting resources.

## State and source control

- Keep Terraform state and plan files private; they can contain sensitive information.
- Do not commit `terraform.tfvars`, state files, or saved plans.
- For team or production use, configure a secure remote backend with access controls,
  encryption, backups/versioning, and locking appropriate to your Terraform version.
- The example uses the default local state backend for a simple lab. Do not share one local
  state file across team members.
