terraform {
  required_version = ">= 1.6.0"

terraform {
  backend "s3" {
    bucket         = "cet11-grp1-terraform-state"
    key            = "prod/iot-core/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cet11-grp1-terraform-lock"
    encrypt        = true
  }
}

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
}
