# dev, staging and prod call the same module. Only these values differ.
module "web" {
  source = "../modules/web-env"

  environment = "prod"
  owner       = "maamohaimin"

  vpc_cidr = "10.42.0.0/16"
  public_subnets = {
    a = { cidr_block = "10.42.1.0/24", az_index = 0 }
    b = { cidr_block = "10.42.2.0/24", az_index = 1 }
  }

  instance_type       = "t3.small"
  cpu_alarm_threshold = 70

  db_password_parameter_name = "/acs730/a1/prod/db_password"
}
