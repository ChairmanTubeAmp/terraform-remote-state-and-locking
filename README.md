# terraform-remote-state-and-locking
A Terraform file that initializes an encrypted, replicated S3 bucket for storing remote state and creates a DynamoDB table for locking.

Assumes us-east-2 for most resources and us-west-1 for the cross region replica S3 bucket.

Due to https://github.com/terraform-providers/terraform-provider-aws/issues/6046 you must specify a source kms key in the AWS GUI. Use the key ARN for aws_s3_bucket.terraform_state given by `terraform apply`
