# terraform-remote-state-and-locking
A Terraform file that initializes an encrypted, replicated S3 bucket for storing remote state and creates a DynamoDB table for locking.

Assumes us-east-2 for most resources and us-west-1 for the cross region replica S3 bucket.
