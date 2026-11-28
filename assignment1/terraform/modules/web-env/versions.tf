# A module declares which provider it needs, but never configures one.
# The provider block (region, default tags) lives in each environment
# directory, so the same module can be called from dev, staging and prod.
terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}
