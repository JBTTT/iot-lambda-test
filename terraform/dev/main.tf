provider "aws" {
  region = var.region
}

module "lambda_sns" {
  source       = "../modules/lambda_sns"
  name_prefix  = var.name_prefix
  env          = var.env
  alert_email  = "perseverancejb@hotmail.com"

  # Using local archive_file; keep S3 vars empty
  lambda_s3_bucket = ""
  lambda_s3_key    = ""
}

module "iot_core" {
  source             = "../modules/iot_core"
  name_prefix        = var.name_prefix
  env                = var.env
  lambda_function_arn = module.lambda_sns.lambda_function_arn

  # You can change the topic if you like
  iot_topic = "cet11/grp1/dev/telemetry"
}

# Allow IoT Core rule to invoke the Lambda
resource "aws_lambda_permission" "allow_iot" {
  statement_id  = "AllowExecutionFromIotCore"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_sns.lambda_function_arn
  principal     = "iot.amazonaws.com"
  source_arn    = module.iot_core.rule_arn
}
