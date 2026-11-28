# Task 7: one CloudWatch alarm on a real metric.
#
# CPUUtilization is reported every 5 minutes by basic monitoring even on an
# idle instance, so the alarm leaves INSUFFICIENT_DATA and settles in OK.
# A request-count metric on a server nobody calls would never get data.

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name        = "${local.name}-web-cpu-high"
  alarm_description = "Average CPU on the ${var.environment} web server above ${var.cpu_alarm_threshold}% for ${var.alarm_evaluation_periods} x 5 minutes."

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  dimensions = {
    InstanceId = aws_instance.web.id
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = var.cpu_alarm_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  tags = merge(local.common_tags, { Name = "${local.name}-web-cpu-high" })
}
