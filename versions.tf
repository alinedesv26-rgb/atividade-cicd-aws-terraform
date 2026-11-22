terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # O bucket S3 deve ser criado previamente. Veja README.md.
  backend "s3" {}
}
