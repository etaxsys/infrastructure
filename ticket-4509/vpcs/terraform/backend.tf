# terraform {
#   backend "s3" {
#     bucket         = "dev-agenerette-aws-tf-state-bucket"
#     key            = "terraform/state/vpc1"
#     region         = "us-east-1"
#     dynamodb_table = "dev-agenerette-aws-terraform-state-vpc1-lock"
#     encrypt        = true
#   }
# }
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-136091176431"
    key            = "vpc1/cloudposse-terraform.tfstate" # Path to the state file
    region         = "us-east-1"              # Bucket region
    dynamodb_table = "terraform-locks"        # DynamoDB table for state locking
    encrypt        = true                     # Encrypt state file
  }
}