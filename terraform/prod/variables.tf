variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Base name prefix"
  type        = string
  default     = "cet11-grp1"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "prod"
}
