provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  alias  = "west"
  region = "us-west-1"
}

resource "aws_kms_key" "tf_key" {
  description = "This key is used to encrypt terraform bucket objects"
}

resource "aws_kms_key" "tf_key_replica" {
  description = "This key is used to encrypt the terraform bucket replica"
  provider    = aws.west
}

resource "aws_iam_role" "replication" {
  name = "tf-iam-role-replication"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY

}

resource "aws_iam_policy" "replication" {
  name = "tf-iam-role-policy-replication"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionForReplication"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.source.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags",
        "s3:GetObjectVersionTagging"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.destination.arn}/*"
    },
    {
      "Action":[
        "kms:Decrypt"
      ],
      "Effect":"Allow",
      "Condition": {
        "StringLike": {
          "kms:ViaService":"s3.us-east-2.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "${aws_s3_bucket.source.arn}/*"
          ]
        }
      },
      "Resource":[
        "${aws_kms_key.tf_key.arn}"
      ]
    },
    {
      "Action":[
        "kms:Encrypt"
      ],
      "Effect":"Allow",
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.us-west-1.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "${aws_s3_bucket.destination.arn}/*"
          ]
        }
      },
      "Resource":[
        "${aws_kms_key.tf_key_replica.arn}"
      ]
    }
  ]
}
POLICY

}

resource "aws_iam_policy_attachment" "replication" {
  name       = "tf-iam-role-attachment-replication"
  roles      = [aws_iam_role.replication.name]
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket" "destination" {
  bucket   = "mycorp-terraform-state-cross-region-replica"
  provider = aws.west

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.tf_key_replica.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Terraform state bucket replica"
  }
}

resource "aws_s3_bucket" "source" {
  bucket = "mycorp-terraform-state"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.tf_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  lifecycle_rule {
    enabled = true

    noncurrent_version_expiration {
      days = 90
    }
  }

  replication_configuration {
    role = aws_iam_role.replication.arn

    rules {
      id     = "mycorp-terraform-state-cross-region-replica"
      prefix = ""
      status = "Enabled"

      source_selection_criteria {
        sse_kms_encrypted_objects {
          enabled = true
        }
      }

      destination {
        bucket             = aws_s3_bucket.destination.arn
        storage_class      = "STANDARD"
        replica_kms_key_id = aws_kms_key.tf_key_replica.arn
      }
    }
  }

  tags = {
    Name = "Terraform state bucket"
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "mycorp_terraform_state_lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
