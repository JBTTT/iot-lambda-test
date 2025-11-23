variable "name_prefix" {
  description = "Base name prefix (e.g. cet11-grp1)"
  type        = string
}

variable "env" {
  description = "Environment (dev, prod)"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to invoke"
  type        = string
}

variable "iot_topic" {
  description = "MQTT topic to listen on"
  type        = string
  default     = "cet11/grp1/telemetry"
}
