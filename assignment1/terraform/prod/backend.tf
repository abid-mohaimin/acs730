# Same bucket for all three environments, a DIFFERENT key for each.
# When you copy this directory to staging/ or prod/, change the key in the
# same edit, before you run terraform init.
terraform {
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  backend "s3" {
    bucket       = "acs730-tfstate-072374718788"
    key          = "assignment1/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
