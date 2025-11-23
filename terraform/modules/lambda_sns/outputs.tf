output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.iot_alert.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}
