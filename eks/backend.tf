terraform {
  required_version = "~> 1.9.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.49.0"
    }
  }
  backend "s3" {
    bucket         = "terraform-statelock-devops"
    region         = "ap-south-1"
    key            = "eks/terraform.tfstate"
    #dynamodb_table = "Lock-Files"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = var.aws-region
}
