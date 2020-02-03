# terraform-remote-state-and-locking
A stand-alone Terraform module that initializes an encrypted, replicated S3 bucket for storing remote state and creates a DynamoDB table for locking.

Assumes us-east-2 for most resources and us-west-1 for the cross region replica S3 bucket.

Changes:
* Now 0.12 compatible.
* Handles all KMS replication permissions correctly thanks to [@f0rk](https://github.com/f0rk)
