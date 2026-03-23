terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
  backend "s3" {
    bucket  = "tf-state-security-poc"
    key     = "security-poc/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
