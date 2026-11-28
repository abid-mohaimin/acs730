# dev, staging and prod call the same module. Only these values differ.
module "web" {
  source = "../modules/web-env"

  environment = "dev"
  owner       = "maamohaimin"

  vpc_cidr = "10.40.0.0/16"
  public_subnets = {
    a = { cidr_block = "10.40.1.0/24", az_index = 0 }
  }

  instance_type       = "t3.micro"
  cpu_alarm_threshold = 90

  db_password_parameter_name = "/acs730/a1/dev/db_password"
}
