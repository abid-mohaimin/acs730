# Inputs are the things that DIFFER between dev, staging and prod.
# Anything identical in all three is a local in main.tf, not an input.

variable "environment" {
  description = "Which environment this copy of the module is: dev, staging or prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "owner" {
  description = "Seneca username, tagged onto everything. An input so another student could reuse the module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for this environment's VPC. Different per environment so they never overlap."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR, for example 10.40.0.0/16."
  }
}

variable "public_subnets" {
  description = "Public subnets to create, keyed by a short stable name. for_each, not count, so removing one key never renumbers the others."
  type = map(object({
    cidr_block = string
    az_index   = number
  }))

  validation {
    condition     = length(var.public_subnets) >= 1
    error_message = "At least one public subnet is required."
  }
}

variable "instance_type" {
  description = "Instance type for the web server. Prod may be one size up."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Stay small: t3.micro or t3.small. The term budget is $50 in total."
  }
}

variable "ingress_rules" {
  description = "Inbound rules for the web security group. SSH is refused: Session Manager is the way in."
  type = list(object({
    description = string
    port        = number
    cidr_blocks = list(string)
  }))
  default = [
    { description = "HTTP from anywhere", port = 80, cidr_blocks = ["0.0.0.0/0"] },
  ]

  validation {
    condition     = alltrue([for r in var.ingress_rules : r.port != 22])
    error_message = "Port 22 is not allowed. Use Session Manager (LabInstanceProfile) instead of SSH."
  }
}

variable "instance_profile_name" {
  description = "Pre-made instance profile. Gives the instance the SSM agent permissions Session Manager needs, with no IAM writes."
  type        = string
  default     = "LabInstanceProfile"
}

variable "db_password_parameter_name" {
  description = "SSM Parameter Store name holding this environment's placeholder DB password. Created by hand with aws ssm put-parameter BEFORE the first plan; Terraform only reads it."
  type        = string

  validation {
    condition     = startswith(var.db_password_parameter_name, "/")
    error_message = "Parameter names must be a full path starting with /, for example /acs730/a1/prod/db_password."
  }
}

variable "cpu_alarm_threshold" {
  description = "Average CPU percent above which the alarm fires. Tighter in prod."
  type        = number

  validation {
    condition     = var.cpu_alarm_threshold > 0 && var.cpu_alarm_threshold <= 100
    error_message = "cpu_alarm_threshold must be between 1 and 100."
  }
}

variable "alarm_evaluation_periods" {
  description = "How many consecutive 5-minute periods must breach before the alarm goes to ALARM."
  type        = number
  default     = 2
}
