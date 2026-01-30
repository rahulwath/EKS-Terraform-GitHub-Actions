terraform {
  required_version = "~> 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.49.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-statelock-devops"
    key          = "eks/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
    # dynamodb_table = "Lock-Files" # optional, only if you want DynamoDB locking
  }
}

provider "aws" {
  region = var.aws_region
}
