variable "name_prefix" {
  description = "Base name prefix for all resources (e.g. cet11-grp1)"
  type        = string
}

variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "lambda_s3_bucket" {
  description = "S3 bucket where Lambda zip is stored (optional if using local archive)"
  type        = string
  default     = ""
}

variable "lambda_s3_key" {
  description = "S3 key for the Lambda zip (optional if using local archive)"
  type        = string
  default     = ""
}

variable "lambda_zip_path" {
  description = "Local path to Lambda source zip (if using archive_file)"
  type        = string
  default     = "../../lambda_src/lambda.zip"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 128
}

variable "alert_email" {
  description = "Email address for SNS subscription"
  type        = string
}
