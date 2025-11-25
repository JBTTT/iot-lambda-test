###############################################
# Terraform - PROD Environment
# Environment: prod
# Region: us-east-1
###############################################

provider "aws" {
  region = var.region
}

locals {
  env         = var.env            # "prod"
  name_prefix = var.name_prefix    # "cet11-grp1"
}

# --------------------------------------------
# Lambda + SNS Module for PROD
# --------------------------------------------
module "lambda_sns" {
  source       = "../modules/lambda_sns"
  name_prefix  = local.name_prefix
  env          = local.env
  alert_email  = "perseverancejb@hotmail.com"

  # Lambda packaged locally
  lambda_s3_bucket = ""
  lambda_s3_key    = ""
}

# --------------------------------------------
# IoT Core Rule Module for PROD
# --------------------------------------------
module "iot_core" {
  source              = "../modules/iot_core"
  name_prefix         = local.name_prefix
  env                 = local.env
  lambda_function_arn = module.lambda_sns.lambda_function_arn

  # PROD MQTT Topic (fully isolated)
  iot_topic = "cet11/grp1/prod/telemetry"
}

# --------------------------------------------
# Allow IoT Rule to Invoke Lambda (PROD)
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

output "prod_lambda_arn" {
  value = module.lambda_sns.lambda_function_arn
}

output "prod_sns_topic_arn" {
  value = module.lambda_sns.sns_topic_arn
}

output "prod_iot_rule_arn" {
  value = module.iot_core.rule_arn
}
