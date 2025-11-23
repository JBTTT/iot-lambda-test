output "lambda_function_arn" {
  value = module.lambda_sns.lambda_function_arn
}

output "sns_topic_arn" {
  value = module.lambda_sns.sns_topic_arn
}

output "iot_rule_arn" {
  value = module.iot_core.rule_arn
}
