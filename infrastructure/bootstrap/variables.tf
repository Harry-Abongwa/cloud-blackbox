variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "tf_state_bucket" {
  type        = string
  description = "S3 bucket name for Terraform remote state"
}

variable "tf_lock_table" {
  type        = string
  description = "DynamoDB table name for Terraform state locking"
}
