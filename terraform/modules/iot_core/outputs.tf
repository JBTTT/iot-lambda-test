output "rule_arn" {
  value       = aws_iot_topic_rule.temperature_to_lambda.arn
  description = "ARN of the IoT topic rule"
}

