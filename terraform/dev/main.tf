###############################################
# Terraform - DEV Environment
# Environment: dev
# Region: us-east-1
###############################################

provider "aws" {
  region = var.region
}

locals {
  env         = var.env
  name_prefix = var.name_prefix
}

# --------------------------------------------
# Lambda + SNS Module for DEV
# --------------------------------------------
module "lambda_sns" {
  source       = "../modules/lambda_sns"
  name_prefix  = local.name_prefix
  env          = local.env
  alert_email  = "perseverancejb@hotmail.com"

  # Using local archive packaging (no S3)
  lambda_s3_bucket = ""
  lambda_s3_key    = ""
}

# --------------------------------------------
# IoT Core Rule Module for DEV
# --------------------------------------------
module "iot_core" {
  source              = "../modules/iot_core"
  name_prefix         = local.name_prefix
  env                 = local.env
  lambda_function_arn = module.lambda_sns.lambda_function_arn

  # DEV MQTT Topic
  iot_topic = "cet11/grp1/dev/telemetry"
}

# --------------------------------------------
# Allow IoT Rule to Invoke Lambda
# --------------------------------------------
resource "aws_lambda_permission" "allow_iot" {
  statement_id  = "AllowExecutionFromIotCore"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_sns.lambda_function_arn
  principal     = "iot.amazonaws.com"
  source_arn    = module.iot_core.rule_arn
}

###############################################
# Outputs
###############################################

output "dev_lambda_arn" {
  value = module.lambda_sns.lambda_function_arn
}

output "dev_sns_topic_arn" {
  value = module.lambda_sns.sns_topic_arn
}

output "dev_iot_rule_arn" {
  value = module.iot_core.rule_arn
}
