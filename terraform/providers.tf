terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "aws-ha-web-app"
      ManagedBy = "terraform"
      Owner     = "jack-salamone"
    }
  }
}
