output "environment" {
  description = "Which environment this module instance built."
  value       = var.environment
}

output "vpc_id" {
  description = "Id of this environment's VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Public subnet ids, keyed like var.public_subnets."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "web_instance_id" {
  description = "Instance id of the web server. Use it with aws ssm start-session."
  value       = aws_instance.web.id
}

output "web_url" {
  description = "URL to curl once the instance has booted."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "cpu_alarm_name" {
  description = "Name of the CloudWatch alarm, for aws cloudwatch describe-alarms."
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "db_password_parameter" {
  description = "Which SSM parameter Terraform read, and which version. Metadata only, never the value."
  value = {
    name    = data.aws_ssm_parameter.db_password.name
    type    = data.aws_ssm_parameter.db_password.type
    version = data.aws_ssm_parameter.db_password.version
  }
}

output "db_password" {
  description = "The decrypted value, for a consumer that needs it. Sensitive, so plan and apply print (sensitive value)."
  value       = data.aws_ssm_parameter.db_password.value
  sensitive   = true
}
