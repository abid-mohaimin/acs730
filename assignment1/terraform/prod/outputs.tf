output "environment" {
  value = module.web.environment
}

output "vpc_id" {
  value = module.web.vpc_id
}

output "subnet_ids" {
  value = module.web.subnet_ids
}

output "web_instance_id" {
  value = module.web.web_instance_id
}

output "web_url" {
  value = module.web.web_url
}

output "cpu_alarm_name" {
  value = module.web.cpu_alarm_name
}

output "db_password_parameter" {
  value = module.web.db_password_parameter
}
