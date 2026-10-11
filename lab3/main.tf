terraform {
  # Same Terraform the course installs (scripts/install-lab-tools.sh) and the
  # deploy workflow uses. use_lockfile needs 1.10 or newer.
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # One shared state for the workstation and GitHub Actions.
  # The bucket is created once by hand and is not managed here.
  backend "s3" {
    bucket       = "acs730-tfstate-072374718788"
    key          = "lab3/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "ACS730"
      Lab       = "lab3"
      ManagedBy = "terraform"
    }
  }
}

variable "aws_region" {
  description = "Region for the lab resources. Must match the backend region."
  type        = string
  default     = "us-east-1"
}

# Bump this number in a pull request to prove the pipeline modifies the
# existing security group in place instead of creating a second one.
locals {
  revision = "1"
}

# A free resource that is easy to see in the console. Tag changes are an
# in-place update, so the plan shows "~ update in-place", not "+ create".
resource "aws_security_group" "lab3" {
  name        = "acs730-lab3-sg"
  description = "ACS730 Lab 3 pipeline test group, no inbound rules"

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "acs730-lab3-sg"
    Revision = local.revision
  }
}

output "security_group_id" {
  value = aws_security_group.lab3.id
}

output "revision" {
  value = local.revision
}
