terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  base_name = "${var.name_prefix}-${var.env}"
}

resource "aws_iot_topic_rule" "temperature_to_lambda" {
  name        = "${local.base_name}-iot-rule"
  description = "Route IoT messages to Lambda for alerts"
  enabled     = true
  sql_version = "2016-03-23"

  # All messages from the specified topic go to the Lambda
  sql = "SELECT * FROM '${var.iot_topic}'"

  lambda {
    function_arn = var.lambda_function_arn
  }
}
